class TournamentInvitation {
  static const publicBase = 'https://profgans.github.io/DartTunier/invite/';
  static String link(String token) => Uri.parse(
    publicBase,
  ).replace(queryParameters: {'tournament': token}).toString();
  static String? parse(Uri uri) {
    final native =
        uri.scheme == 'dartturnier' &&
        uri.host == 'tournament' &&
        uri.path == '/join';
    final web =
        uri.scheme == 'https' &&
        uri.host == 'profgans.github.io' &&
        uri.path == '/DartTunier/invite/';
    final parameter = native ? 'token' : 'tournament';
    if ((!native && !web) ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasFragment ||
        uri.queryParametersAll[parameter]?.length != 1) {
      return null;
    }
    final token = uri.queryParameters[parameter];
    return token != null &&
            RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
            ).hasMatch(token)
        ? token
        : null;
  }
}
