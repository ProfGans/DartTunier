#pragma once
#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>
#include <memory>

namespace camera_windows {
// Host-arrival timestamps use one monotonic clock for all cameras.
void BufferAutoscoreVideo(int64_t id, const uint8_t* data, uint32_t length,
                         uint32_t width, uint32_t height);
void RemoveAutoscoreVideo(int64_t id);
std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
CreateAutoscoreVideoChannel(flutter::BinaryMessenger* messenger);
}
