#include "autoscore_video_frame.h"
#include "autoscore_color_encoder.h"
#include <chrono>
#include <fstream>
#include <string>
#include <cstdlib>
#include <iostream>

void check(bool value) {
  if (!value) { std::cerr << "Native conversion mismatch\n"; std::exit(1); }
}
int main(int argc, char** argv) {
  if (argc == 4) {
    std::ifstream input(argv[1], std::ios::binary);
    std::vector<uint8_t> rgb((std::istreambuf_iterator<char>(input)), std::istreambuf_iterator<char>());
    const auto width = static_cast<uint32_t>(std::stoul(argv[2]));
    const auto height = static_cast<uint32_t>(std::stoul(argv[3]));
    check(rgb.size() == static_cast<size_t>(width) * height * 3);
    std::vector<uint8_t> png;
    const auto start = std::chrono::steady_clock::now();
    check(camera_windows::EncodeAutoscoreColorPng(rgb, width, height, png));
    const auto milliseconds = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count();
    std::ofstream(std::string(argv[1]) + ".png", std::ios::binary).write(reinterpret_cast<const char*>(png.data()), png.size());
    std::cout << "{\"milliseconds\":" << milliseconds << ",\"pngBytes\":" << png.size() << "}\n";
    return 0;
  }
  for (const auto dimensions : {std::pair<uint32_t, uint32_t>{1280,720}, {1920,1080}, {800,601}, {320,240}, {1,1}}) {
    const auto width = dimensions.first, height = dimensions.second;
    std::vector<uint8_t> bgra(width * height * 4);
    for (size_t i = 0; i < bgra.size(); ++i) bgra[i] = static_cast<uint8_t>((i * 31 + i / 17) % 256);
    const auto frame = camera_windows::ConvertAutoscoreVideo(bgra.data(), width, height);
    const uint32_t w = frame.width, h = frame.height;
    if (!frame.gray.empty()) {
    for (uint32_t y = 0; y < h; ++y) {
      for (uint32_t x = 0; x < w; ++x) {
        const auto src = ((y * height / h) * width + x * width / w) * 4;
        const auto expected = (bgra[src + 2] * 77 + bgra[src + 1] * 150 + bgra[src] * 29) >> 8;
        check(frame.gray[y * w + x] == expected);
      }
    }
    }
    for (uint32_t y = 0; y < static_cast<uint32_t>(frame.color_height); ++y) {
      for (uint32_t x = 0; x < static_cast<uint32_t>(frame.color_width); ++x) {
        const auto dx = x * w / frame.color_width, dy = y * h / frame.color_height;
        const auto src = ((dy * height / h) * width + dx * width / w) * 4;
        const auto dst = (y * frame.color_width + x) * 3;
        check(frame.rgb[dst] == bgra[src + 2]);
        check(frame.rgb[dst + 1] == bgra[src + 1]);
        check(frame.rgb[dst + 2] == bgra[src]);
      }
    }
    std::cout << width << "x" << height << ": exact gray/RGB samples; payload "
              << frame.gray.size() + frame.rgb.size() << " vs " << w * h * 3 << " bytes\n";
    std::vector<uint8_t> png;
    const auto start = std::chrono::steady_clock::now();
    check(camera_windows::EncodeAutoscoreColorPng(frame.rgb, frame.color_width, frame.color_height, png));
    const auto milliseconds = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count();
    const auto basename = std::string("build/autoscore_native_probe/color_") + std::to_string(width) + "x" + std::to_string(height);
    std::ofstream(basename + ".png", std::ios::binary).write(reinterpret_cast<const char*>(png.data()), png.size());
    std::ofstream(basename + ".rgb", std::ios::binary).write(reinterpret_cast<const char*>(frame.rgb.data()), frame.rgb.size());
    std::cout << "  WIC PNG " << png.size() << " bytes, " << milliseconds << " ms\n";
  }
}
