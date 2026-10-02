class ScorerJoinCode {
  static final _pattern = RegExp(r'^[A-F0-9]{32}$');
  static String link(String code) => Uri(
    scheme: 'dartturnier',
    host: 'scorer',
    path: '/join',
    queryParameters: {'code': code},
  ).toString();
  static String? parse(String value) {
    final raw = value.trim().toUpperCase();
    if (_pattern.hasMatch(raw)) return raw;
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'dartturnier' ||
        uri.host != 'scorer' ||
        uri.path != '/join' ||
        uri.hasPort ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty ||
        uri.queryParametersAll['code']?.length != 1) {
      return null;
    }
    final code = uri.queryParameters['code']!.toUpperCase();
    return _pattern.hasMatch(code) ? code : null;
  }
}

class LobbyMember {
  const LobbyMember(this.id, this.name);
  final String id, name;
  factory LobbyMember.fromJson(Map<String, dynamic> json) =>
      LobbyMember(json['user_id'] as String, json['display_name'] as String);
}

class ScorerLobby {
  ScorerLobby.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      code = json['code'] as String,
      open = json['open'] as bool,
      expiresAt = DateTime.parse(json['expires_at'] as String),
      members = List.unmodifiable([
        for (final m in json['members'] as List? ?? [])
          LobbyMember.fromJson(Map<String, dynamic>.from(m as Map)),
      ]);
  final String id, code;
  final bool open;
  final DateTime expiresAt;
  final List<LobbyMember> members;
}

class ScorerInvitation {
  const ScorerInvitation(this.id, this.hostName);
  final String id, hostName;
  factory ScorerInvitation.fromJson(Map<String, dynamic> json) =>
      ScorerInvitation(json['id'] as String, json['host_name'] as String);
}

class ScorerInviteCandidate {
  const ScorerInviteCandidate(this.id, this.name, this.groups);
  final String id, name, groups;
  factory ScorerInviteCandidate.fromJson(Map<String, dynamic> json) =>
      ScorerInviteCandidate(
        json['user_id'] as String,
        json['display_name'] as String,
        json['groups'] as String,
      );
}
