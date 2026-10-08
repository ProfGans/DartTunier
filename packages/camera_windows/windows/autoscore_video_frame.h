#pragma once
#include <algorithm>
#include <cstdint>
#include <vector>

namespace camera_windows {
struct AutoscoreVideoFrame {
  int64_t time = 0, sequence = 0;
  int width = 0, height = 0, color_width = 0, color_height = 0;
  std::vector<uint8_t> rgb, gray;
  std::vector<uint8_t> color_png;
  int64_t color_encode_us = 0;
};

// Identical detail luminance and nearest-neighbor color samples to the former
// Dart conversion, without transferring full-resolution RGB to Dart.
inline AutoscoreVideoFrame ConvertAutoscoreVideo(const uint8_t* bgra,
                                                uint32_t width,
                                                uint32_t height) {
  AutoscoreVideoFrame frame;
  const uint32_t w = std::min(width, uint32_t(1280));
  const uint32_t h = std::max(uint32_t(1), height * w / width);
  const uint32_t cw = std::min(w, uint32_t(640));
  const uint32_t ch = std::max(uint32_t(1), (h * cw + w / 2) / w);
  frame.width = static_cast<int>(w); frame.height = static_cast<int>(h);
  frame.color_width = static_cast<int>(cw); frame.color_height = static_cast<int>(ch);
  if (w > 640) frame.gray.resize(w * h);
  frame.rgb.resize(cw * ch * 3);
  if (!frame.gray.empty()) {
  for (uint32_t y = 0; y < h; ++y) {
    for (uint32_t x = 0; x < w; ++x) {
      const auto src = ((y * height / h) * width + x * width / w) * 4;
      frame.gray[y * w + x] = static_cast<uint8_t>(
          (bgra[src + 2] * 77 + bgra[src + 1] * 150 + bgra[src] * 29) >> 8);
    }
  }
  }
  for (uint32_t y = 0; y < ch; ++y) {
    for (uint32_t x = 0; x < cw; ++x) {
      const auto dx = x * w / cw, dy = y * h / ch;
      const auto src = ((dy * height / h) * width + dx * width / w) * 4;
      const auto dst = (y * cw + x) * 3;
      frame.rgb[dst] = bgra[src + 2];
      frame.rgb[dst + 1] = bgra[src + 1];
      frame.rgb[dst + 2] = bgra[src];
    }
  }
  return frame;
}
}
