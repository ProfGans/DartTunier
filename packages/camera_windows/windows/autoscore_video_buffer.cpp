#include "autoscore_video_buffer.h"
#include "autoscore_video_frame.h"
#include "autoscore_color_encoder.h"
#include <flutter/standard_method_codec.h>
#include <algorithm>
#include <chrono>
#include <deque>
#include <map>
#include <mutex>
#include <vector>

namespace camera_windows {
namespace {
using flutter::EncodableValue;
using flutter::EncodableMap;
using flutter::EncodableList;
struct VideoCamera { int64_t last_time = 0, sequence = 0, dropped = 0, generation = 0; std::deque<AutoscoreVideoFrame> frames; };
std::mutex video_mutex;
std::map<int64_t, VideoCamera> video_cameras;
int64_t video_generation = 0;
}
void RemoveAutoscoreVideo(int64_t id) {
  std::lock_guard<std::mutex> lock(video_mutex);
  video_cameras.erase(id);
}
void BufferAutoscoreVideo(int64_t id, const uint8_t* data, uint32_t length,
                         uint32_t width, uint32_t height) {
  const int64_t now = std::chrono::duration_cast<std::chrono::microseconds>(
      std::chrono::steady_clock::now().time_since_epoch()).count();
  if (width == 0 || height == 0 ||
      static_cast<uint64_t>(width) * height * 4 != length) return;
  int64_t generation;
  {
    std::lock_guard<std::mutex> lock(video_mutex);
    auto camera = video_cameras.find(id);
    if (camera == video_cameras.end() || now - camera->second.last_time < 20000) return;
    generation = camera->second.generation;
  }
  auto frame = ConvertAutoscoreVideo(data, width, height);
  const auto encode_started = std::chrono::steady_clock::now();
  if (EncodeAutoscoreColorPng(frame.rgb, frame.color_width, frame.color_height,
                            frame.color_png)) {
    if (frame.gray.empty()) {
      frame.gray.resize(frame.width * frame.height);
      for (size_t i = 0; i < frame.gray.size(); ++i) {
        const auto p = i * 3;
        frame.gray[i] = static_cast<uint8_t>((frame.rgb[p] * 77 +
            frame.rgb[p + 1] * 150 + frame.rgb[p + 2] * 29) >> 8);
      }
    }
    std::vector<uint8_t>().swap(frame.rgb);
  }
  frame.color_encode_us = std::chrono::duration_cast<std::chrono::microseconds>(
      std::chrono::steady_clock::now() - encode_started).count();
  frame.time = now;
  std::lock_guard<std::mutex> lock(video_mutex);
  auto camera = video_cameras.find(id);
  if (camera == video_cameras.end() || camera->second.generation != generation ||
      now - camera->second.last_time < 20000) return;
  auto& state = camera->second;
  frame.sequence = ++state.sequence;
  state.last_time = now;
  if (state.frames.size() >= 6) { state.frames.pop_front(); ++state.dropped; }
  state.frames.push_back(std::move(frame));
}
std::unique_ptr<flutter::MethodChannel<EncodableValue>>
CreateAutoscoreVideoChannel(flutter::BinaryMessenger* messenger) {
  auto channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "dart_tournament/autoscore_video", &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler([](const auto& call, auto result) {
    if (call.method_name() == "configure") {
      std::lock_guard<std::mutex> lock(video_mutex);
      const auto* ids = call.arguments() ? std::get_if<EncodableList>(call.arguments()) : nullptr;
      if (!ids || ids->size() > 3) { result->Error("invalid_ids", "At most three camera IDs required"); return; }
      video_cameras.clear();
      ++video_generation;
      for (const auto& value : *ids) {
        if (const auto* id = std::get_if<int64_t>(&value)) video_cameras[*id].generation = video_generation;
        else if (const auto* id32 = std::get_if<int32_t>(&value)) video_cameras[*id32].generation = video_generation;
        else { video_cameras.clear(); result->Error("invalid_id", "Camera ID must be integer"); return; }
      }
      result->Success(EncodableValue(true));
    } else if (call.method_name() == "read") {
      const int64_t read_time = std::chrono::duration_cast<std::chrono::microseconds>(
          std::chrono::steady_clock::now().time_since_epoch()).count();
      EncodableList frames;
      {
      std::lock_guard<std::mutex> lock(video_mutex);
      for (auto& entry : video_cameras) {
        for (auto& f : entry.second.frames) {
          frames.push_back(EncodableValue(EncodableMap{
            {EncodableValue("cameraId"), EncodableValue(entry.first)},
            {EncodableValue("timestampUs"), EncodableValue(f.time)},
            {EncodableValue("ageUs"), EncodableValue(std::max(int64_t(0), read_time - f.time))},
            {EncodableValue("sequence"), EncodableValue(f.sequence)},
            {EncodableValue("dropped"), EncodableValue(entry.second.dropped)},
            {EncodableValue("width"), EncodableValue(f.width)},
            {EncodableValue("height"), EncodableValue(f.height)},
            {EncodableValue("colorWidth"), EncodableValue(f.color_width)},
            {EncodableValue("colorHeight"), EncodableValue(f.color_height)},
            {EncodableValue("colorImage"), f.color_png.empty() ? EncodableValue() : EncodableValue(std::move(f.color_png))},
            {EncodableValue("colorEncodeUs"), EncodableValue(f.color_encode_us)},
            {EncodableValue("gray"), f.gray.empty() ? EncodableValue() : EncodableValue(std::move(f.gray))},
            {EncodableValue("rgb"), EncodableValue(std::move(f.rgb))}}));
        }
        entry.second.frames.clear();
      }
      }
      // Encoding/copying the channel reply must not block camera callbacks.
      result->Success(EncodableValue(frames));
    } else { result->NotImplemented(); }
  });
  return channel;
}
}
