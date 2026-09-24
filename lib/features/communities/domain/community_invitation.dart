class CommunityInvitation {
  const CommunityInvitation._();

  static String link(String code) => Uri(
    scheme: 'dartturnier',
    host: 'community',
    path: '/join',
    queryParameters: {'code': code.trim().toUpperCase()},
  ).toString();

  static String? codeFromLink(Uri uri) {
    if (uri.scheme != 'dartturnier' ||
        uri.host != 'community' ||
        uri.path != '/join' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasFragment ||
        uri.queryParametersAll['code']?.length != 1) {
      return null;
    }
    final code = uri.queryParameters['code']?.trim().toUpperCase();
    return code != null && RegExp(r'^[A-Z0-9]{8}$').hasMatch(code)
        ? code
        : null;
  }

  static String? parseInput(String input) {
    final code = input.trim().toUpperCase();
    if (RegExp(r'^[A-Z0-9]{8}$').hasMatch(code)) return code;
    final uri = Uri.tryParse(input.trim());
    return uri == null ? null : codeFromLink(uri);
  }
}
