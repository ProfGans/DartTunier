#pragma once
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <wincodec.h>
#include <wrl/client.h>
#include <cstdint>
#include <vector>
#include <utility>

namespace camera_windows {
// WIC runs on the capture callback thread, outside the camera mutex. Failure
// leaves the original RGB packet available for the compatible Dart fallback.
inline bool EncodeAutoscoreColorPng(const std::vector<uint8_t>& rgb,
                                   uint32_t width, uint32_t height,
                                   std::vector<uint8_t>& output) {
  using Microsoft::WRL::ComPtr;
  output.clear();
  const HRESULT initialized = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  if (FAILED(initialized) && initialized != RPC_E_CHANGED_MODE) return false;
  struct ComScope {
    bool initialized;
    ~ComScope() { if (initialized) CoUninitialize(); }
  } scope{SUCCEEDED(initialized)};
  ComPtr<IWICImagingFactory> factory;
  ComPtr<IStream> stream;
  ComPtr<IWICBitmapEncoder> encoder;
  ComPtr<IWICBitmapFrameEncode> frame;
  ComPtr<IPropertyBag2> options;
  if (FAILED(CoCreateInstance(CLSID_WICImagingFactory, nullptr,
      CLSCTX_INPROC_SERVER, IID_PPV_ARGS(factory.GetAddressOf()))) ||
      FAILED(CreateStreamOnHGlobal(nullptr, TRUE, stream.GetAddressOf())) ||
      FAILED(factory->CreateEncoder(GUID_ContainerFormatPng, nullptr, encoder.GetAddressOf())) ||
      FAILED(encoder->Initialize(stream.Get(), WICBitmapEncoderNoCache)) ||
      FAILED(encoder->CreateNewFrame(frame.GetAddressOf(), options.GetAddressOf())) ||
      FAILED(frame->Initialize(options.Get())) ||
      FAILED(frame->SetSize(width, height))) return false;
  WICPixelFormatGUID format = GUID_WICPixelFormat24bppRGB;
  if (FAILED(frame->SetPixelFormat(&format))) return false;
  std::vector<uint8_t> bgr;
  const uint8_t* pixels = rgb.data();
  if (IsEqualGUID(format, GUID_WICPixelFormat24bppBGR)) {
    bgr = rgb;
    for (size_t i = 0; i < bgr.size(); i += 3) std::swap(bgr[i], bgr[i + 2]);
    pixels = bgr.data();
  } else if (!IsEqualGUID(format, GUID_WICPixelFormat24bppRGB)) {
    return false;
  }
  if (FAILED(frame->WritePixels(height, width * 3,
      static_cast<UINT>(rgb.size()), const_cast<BYTE*>(pixels))) ||
      FAILED(frame->Commit()) || FAILED(encoder->Commit())) return false;
  STATSTG stat{};
  if (FAILED(stream->Stat(&stat, STATFLAG_NONAME)) || stat.cbSize.QuadPart == 0 ||
      stat.cbSize.QuadPart > 16 * 1024 * 1024) return false;
  LARGE_INTEGER beginning{};
  if (FAILED(stream->Seek(beginning, STREAM_SEEK_SET, nullptr))) return false;
  output.resize(static_cast<size_t>(stat.cbSize.QuadPart));
  ULONG read = 0;
  if (FAILED(stream->Read(output.data(), static_cast<ULONG>(output.size()), &read)) ||
      read != output.size()) { output.clear(); return false; }
  return true;
}
}
