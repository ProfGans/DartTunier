class AndroidRelease {
  const AndroidRelease({
    required this.version,
    required this.build,
    required this.url,
    required this.sha256,
    required this.size,
    required this.notes,
  });
  static const repository = 'ProfGans/DartTunier';
  final String version;
  final int build;
  final Uri url;
  final String sha256;
  final int size;
  final String notes;

  static AndroidRelease? fromGitHub(Map<String, dynamic> json) {
    if (json['draft'] != false || json['prerelease'] != false) return null;
    final tag = RegExp(
      r'^v(\d+\.\d+\.\d+)\+(\d+)$',
    ).firstMatch(json['tag_name'] as String? ?? '');
    if (tag == null) return null;
    final build = int.tryParse(tag[2]!);
    if (build == null || build < 1 || build > 2100000000) return null;
    final matches = (json['assets'] as List? ?? [])
        .whereType<Map>()
        .where(
          (asset) =>
              asset['name'] == 'dart-turnier-android.apk' &&
              asset['state'] == 'uploaded',
        )
        .toList();
    if (matches.length != 1) return null;
    final asset = matches.single;
    final uri = Uri.tryParse(asset['browser_download_url'] as String? ?? '');
    final digest = asset['digest'] as String? ?? '';
    final size = asset['size'];
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasQuery ||
        uri.hasFragment ||
        !uri.path.startsWith('/$repository/releases/download/') ||
        !RegExp(r'^sha256:[a-f0-9]{64}$').hasMatch(digest) ||
        size is! int ||
        size < 1 ||
        size > 300 * 1024 * 1024) {
      return null;
    }
    return AndroidRelease(
      version: tag[1]!,
      build: build,
      url: uri,
      sha256: digest.substring(7),
      size: size,
      notes: json['body'] as String? ?? '',
    );
  }

  static AndroidRelease? newest(List<dynamic> releases, int installedBuild) {
    final candidates =
        releases
            .whereType<Map<String, dynamic>>()
            .map(fromGitHub)
            .whereType<AndroidRelease>()
            .where((r) => r.build > installedBuild)
            .toList()
          ..sort((a, b) => b.build.compareTo(a.build));
    return candidates.isEmpty ? null : candidates.first;
  }
}
