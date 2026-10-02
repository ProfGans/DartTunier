#include "autoscoring_ocr.h"
#include <flutter/standard_method_codec.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Globalization.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Media.Ocr.h>
#include <winrt/Windows.Storage.Streams.h>
#include <string>
#include <vector>

namespace {
using Value = flutter::EncodableValue;
using Result = flutter::MethodResult<Value>;

winrt::fire_and_forget Recognize(
    int width, int height, std::vector<uint8_t> pixels,
    std::shared_ptr<Result> reply,
    std::shared_ptr<std::atomic<bool>> alive) {
  winrt::apartment_context origin;
  co_await winrt::resume_background();
  flutter::EncodableList words;
  std::string error;
  bool initialized = false;
  try {
    winrt::init_apartment(winrt::apartment_type::multi_threaded);
    initialized = true;
    using namespace winrt::Windows;
    auto engine = Media::Ocr::OcrEngine::TryCreateFromUserProfileLanguages();
    if (!engine) {
      error = "Keine Windows-OCR-Sprache installiert. Ein Windows-Sprachpaket mit Texterkennung wird benötigt.";
    } else {
      Storage::Streams::DataWriter writer;
      writer.WriteBytes(pixels);
      auto bitmap = Graphics::Imaging::SoftwareBitmap::CreateCopyFromBuffer(
          writer.DetachBuffer(), Graphics::Imaging::BitmapPixelFormat::Bgra8,
          width, height, Graphics::Imaging::BitmapAlphaMode::Ignore);
      auto recognized = engine.RecognizeAsync(bitmap).get();
      const auto text_angle = recognized.TextAngle();
      for (const auto& line : recognized.Lines()) {
        for (const auto& word : line.Words()) {
          const auto box = word.BoundingRect();
          words.emplace_back(flutter::EncodableMap{
            {Value("text"), Value(winrt::to_string(word.Text()))},
            {Value("x"), Value(static_cast<double>(box.X))},
            {Value("y"), Value(static_cast<double>(box.Y))},
            {Value("width"), Value(static_cast<double>(box.Width))},
            {Value("height"), Value(static_cast<double>(box.Height))},
            {Value("textAngle"), Value(text_angle ? text_angle.Value() : 0.0)},
          });
        }
      }
    }
  } catch (const winrt::hresult_error& e) {
    error = winrt::to_string(e.message());
  } catch (const std::exception& e) {
    error = e.what();
  }
  if (initialized) winrt::uninit_apartment();
  if (!alive->load()) co_return;
  co_await origin;
  if (!alive->load()) co_return;
  if (error.empty()) reply->Success(Value(words));
  else reply->Error("ocr_unavailable", error);
}
}

AutoscoringOcr::AutoscoringOcr(flutter::BinaryMessenger* messenger)
    : alive_(std::make_shared<std::atomic<bool>>(true)) {
  channel_ = std::make_unique<flutter::MethodChannel<Value>>(
      messenger, "dart_tournament/autoscoring_ocr",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([alive = alive_](const auto& call,
      std::unique_ptr<Result> result) {
    if (call.method_name() != "recognize") { result->NotImplemented(); return; }
    const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
    if (!args) { result->Error("invalid_image", "Bildargumente fehlen."); return; }
    const auto w = args->find(Value("width")), h = args->find(Value("height")),
        p = args->find(Value("pixels"));
    if (w == args->end() || h == args->end() || p == args->end()) {
      result->Error("invalid_image", "Bildargumente fehlen."); return;
    }
    const auto* width = std::get_if<int32_t>(&w->second);
    const auto* height = std::get_if<int32_t>(&h->second);
    const auto* pixels = std::get_if<std::vector<uint8_t>>(&p->second);
    if (!width || !height || !pixels || *width < 1 || *height < 1 ||
        *width > 2048 || *height > 2048 ||
        pixels->size() != static_cast<size_t>(*width) * *height * 4) {
      result->Error("invalid_image", "Ungültige Bildgröße."); return;
    }
    Recognize(*width, *height, *pixels, std::shared_ptr<Result>(std::move(result)), alive);
  });
}
AutoscoringOcr::~AutoscoringOcr() { alive_->store(false); }
