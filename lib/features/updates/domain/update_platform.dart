import 'dart:ffi';

enum UpdatePlatform {
  android('Android', 'dart-turnier-android.apk'),
  windows('Windows', 'dart-turnier-windows-x64.zip'),
  linux('Linux x64', 'dart-turnier-linux-x64.tar.gz'),
  linuxArm64('Linux ARM64', 'dart-turnier-linux-arm64.tar.gz');

  const UpdatePlatform(this.label, this.assetName);
  final String label, assetName;
  bool get isLinux => this == linux || this == linuxArm64;
  String get manifestPlatform => isLinux ? 'linux' : name;
  String get architecture => this == linuxArm64 ? 'arm64' : 'x64';

  static UpdatePlatform? forDesktopAbi(Abi abi) => switch (abi) {
    Abi.windowsX64 => windows,
    Abi.linuxX64 => linux,
    Abi.linuxArm64 => linuxArm64,
    _ => null,
  };
}
