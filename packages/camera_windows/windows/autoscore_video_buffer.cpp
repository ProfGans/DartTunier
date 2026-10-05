#include "autoscore_video_buffer.h"
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
struct VideoFrame { int64_t time, sequence; int width, height; std::vector<uint8_t> rgb; };
struct VideoCamera { int64_t last_time = 0, sequence = 0, dropped = 0; std::deque<VideoFrame> frames; };
std::mutex video_mutex;
std::map<int64_t, VideoCamera> video_cameras;
}
void RemoveAutoscoreVideo(int64_t id) {
  std::lock_guard<std::mutex> lock(video_mutex);
  video_cameras.erase(id);
}
void BufferAutoscoreVideo(int64_t id, const uint8_t* data, uint32_t length,
                         uint32_t width, uint32_t height) {
  const int64_t now = std::chrono::duration_cast<std::chrono::microseconds>(
      std::chrono::steady_clock::now().time_since_epoch()).count();
  std::lock_guard<std::mutex> lock(video_mutex);
  auto camera = video_cameras.find(id);
  if (camera == video_cameras.end() || width == 0 || height == 0 ||
      static_cast<uint64_t>(width) * height * 4 != length ||
      now - camera->second.last_time < 20000) return;
  // Preserve detail resolution while bounding transfer/memory for 4K cameras.
  const uint32_t w = std::min(width, uint32_t(1280));
  const uint32_t h = std::max(uint32_t(1), height * w / width);
  VideoFrame frame{now, ++camera->second.sequence, static_cast<int>(w),
                   static_cast<int>(h), std::vector<uint8_t>(w * h * 3)};
  for (uint32_t y = 0; y < h; ++y) {
    for (uint32_t x = 0; x < w; ++x) {
      const auto src = ((y * height / h) * width + x * width / w) * 4;
      const auto dst = (y * w + x) * 3;
      frame.rgb[dst] = data[src + 2];
      frame.rgb[dst + 1] = data[src + 1];
      frame.rgb[dst + 2] = data[src];
    }
  }
  auto& state = camera->second;
  state.last_time = now;
  if (state.frames.size() >= 6) { state.frames.pop_front(); ++state.dropped; }
  state.frames.push_back(std::move(frame));
}
std::unique_ptr<flutter::MethodChannel<EncodableValue>>
CreateAutoscoreVideoChannel(flutter::BinaryMessenger* messenger) {
  auto channel = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "dart_tournament/autoscore_video", &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler([](const auto& call, auto result) {
    std::lock_guard<std::mutex> lock(video_mutex);
    if (call.method_name() == "configure") {
      const auto* ids = call.arguments() ? std::get_if<EncodableList>(call.arguments()) : nullptr;
      if (!ids || ids->size() > 3) { result->Error("invalid_ids", "At most three camera IDs required"); return; }
      video_cameras.clear();
      for (const auto& value : *ids) {
        if (const auto* id = std::get_if<int64_t>(&value)) video_cameras[*id] = {};
        else if (const auto* id32 = std::get_if<int32_t>(&value)) video_cameras[*id32] = {};
        else { video_cameras.clear(); result->Error("invalid_id", "Camera ID must be integer"); return; }
      }
      result->Success(EncodableValue(true));
    } else if (call.method_name() == "read") {
      EncodableList frames;
      for (auto& entry : video_cameras) {
        for (auto& f : entry.second.frames) {
          frames.push_back(EncodableValue(EncodableMap{
            {EncodableValue("cameraId"), EncodableValue(entry.first)},
            {EncodableValue("timestampUs"), EncodableValue(f.time)},
            {EncodableValue("sequence"), EncodableValue(f.sequence)},
            {EncodableValue("dropped"), EncodableValue(entry.second.dropped)},
            {EncodableValue("width"), EncodableValue(f.width)},
            {EncodableValue("height"), EncodableValue(f.height)},
            {EncodableValue("rgb"), EncodableValue(std::move(f.rgb))}}));
        }
        entry.second.frames.clear();
      }
      result->Success(EncodableValue(frames));
    } else { result->NotImplemented(); }
  });
  return channel;
}
}
