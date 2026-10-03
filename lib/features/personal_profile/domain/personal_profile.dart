import 'dart_setup.dart';
import 'dart:convert';

class PersonalProfile {
  const PersonalProfile({
    required this.name,
    this.nationality = '',
    this.song = '',
    this.spotify = '',
    this.favoritePlayer = '',
    this.favoriteDouble = '',
    this.picture,
    this.dartSetup = const DartSetup(),
  });
  final String name, nationality, song, spotify, favoritePlayer, favoriteDouble;
  final String? picture;
  final DartSetup dartSetup;
  Map<String, dynamic> toJson() => {
    'version': 1,
    'name': name,
    'nationality': nationality,
    'song': song,
    'spotify': spotify,
    'favoritePlayer': favoritePlayer,
    'favoriteDouble': favoriteDouble,
    'picture': picture,
    'dartSetup': dartSetup.toJson(),
  };
  factory PersonalProfile.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unbekannte Profilversion');
    }
    return PersonalProfile(
      name: json['name'] as String,
      nationality: json['nationality'] as String? ?? '',
      song: json['song'] as String? ?? '',
      spotify: json['spotify'] as String? ?? '',
      favoritePlayer: json['favoritePlayer'] as String? ?? '',
      favoriteDouble: json['favoriteDouble'] as String? ?? '',
      picture: json['picture'] as String?,
      dartSetup: json['dartSetup'] == null
          ? const DartSetup()
          : DartSetup.fromJson(
              Map<String, dynamic>.from(json['dartSetup'] as Map),
            ),
    );
  }
  static bool validSpotify(String value) {
    if (value.trim().isEmpty) return true;
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'open.spotify.com' &&
        uri.userInfo.isEmpty &&
        ((uri.pathSegments.firstOrNull == 'track' &&
                uri.pathSegments.length == 2 &&
                uri.pathSegments[1].isNotEmpty) ||
            (uri.pathSegments.firstOrNull?.startsWith('intl-') == true &&
                uri.pathSegments.length == 3 &&
                uri.pathSegments[1] == 'track'));
  }

  List<int>? get imageBytes => picture == null ? null : base64Decode(picture!);
}
