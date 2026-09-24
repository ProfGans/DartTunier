#include "community_links.h"

#include <windows.h>
#include <shellapi.h>
#include <string>
#include <vector>
#include "app_links/app_links_plugin_c_api.h"

namespace {
void SetString(HKEY key, const wchar_t* name, const std::wstring& value) {
  RegSetValueExW(key, name, 0, REG_SZ,
    reinterpret_cast<const BYTE*>(value.c_str()),
    static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
}
}

void RegisterCommunityLinkProtocol() {
  std::vector<wchar_t> path(32768);
  const DWORD length = GetModuleFileNameW(nullptr, path.data(),
    static_cast<DWORD>(path.size()));
  if (length == 0 || length >= path.size()) return;
  HKEY key = nullptr;
  if (RegCreateKeyExW(HKEY_CURRENT_USER,
      L"Software\\Classes\\dartturnier", 0, nullptr, 0, KEY_WRITE,
      nullptr, &key, nullptr) != ERROR_SUCCESS) return;
  SetString(key, nullptr, L"URL:Dart Turnier Community");
  SetString(key, L"URL Protocol", L"");
  HKEY command = nullptr;
  if (RegCreateKeyExW(key, L"shell\\open\\command", 0, nullptr, 0,
      KEY_WRITE, nullptr, &command, nullptr) == ERROR_SUCCESS) {
    SetString(command, nullptr,
      L"\"" + std::wstring(path.data(), length) + L"\" \"%1\"");
    RegCloseKey(command);
  }
  RegCloseKey(key);
}

bool ForwardCommunityLinkToRunningInstance() {
  int count = 0;
  LPWSTR* args = CommandLineToArgvW(GetCommandLineW(), &count);
  bool has_link = false;
  if (args != nullptr) {
    for (int i = 1; i < count; ++i) {
      if (std::wstring(args[i]).rfind(L"dartturnier://", 0) == 0) has_link = true;
    }
    LocalFree(args);
  }
  if (!has_link) return false;
  const HWND window = FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW",
    L"dart_tournament_manager");
  if (window == nullptr) return false;
  SendAppLink(window);
  if (IsIconic(window)) ShowWindow(window, SW_RESTORE);
  SetForegroundWindow(window);
  return true;
}
