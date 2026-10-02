enum UpdatePlatform {
  android('Android', 'dart-turnier-android.apk'),
  windows('Windows', 'dart-turnier-windows-x64.zip'),
  linux('Linux', 'dart-turnier-linux-x64.tar.gz');

  const UpdatePlatform(this.label, this.assetName);
  final String label, assetName;
}
