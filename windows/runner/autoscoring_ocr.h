#ifndef RUNNER_AUTOSCORING_OCR_H_
#define RUNNER_AUTOSCORING_OCR_H_
#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <atomic>
#include <memory>

// Local Windows OCR adapter; owned by the window and destroyed before its engine.
class AutoscoringOcr {
 public:
  explicit AutoscoringOcr(flutter::BinaryMessenger* messenger);
  ~AutoscoringOcr();
 private:
  std::shared_ptr<std::atomic<bool>> alive_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};
#endif
