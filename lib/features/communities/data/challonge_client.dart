import 'dart:convert';
import 'dart:io';
import '../domain/challonge_tournament.dart';
import 'challonge_public_reader.dart';

/// Legacy v1 is used for historical exports; the API key stays in memory.
class ChallongeClient {
  ChallongeClient({ChallongePublicReader? publicReader})
    : _publicReader = publicReader ?? ChallongePublicReader();
  final ChallongePublicReader _publicReader;
  Future<dynamic> _get(
    String path,
    String apiKey,
    Map<String, String> query,
  ) async {
    if (apiKey.trim().isEmpty) {
      throw const FormatException('Challonge-API-Schlüssel eingeben.');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(
        Uri.https('api.challonge.com', '/v1/$path', {
          ...query,
          'api_key': apiKey.trim(),
        }),
      );
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != 200) {
        throw FormatException(switch (response.statusCode) {
          401 || 403 => 'Challonge-Zugang oder Turnierberechtigung fehlt.',
          404 => 'Challonge-Turnier oder Community nicht gefunden.',
          429 => 'Challonge-Anfragelimit erreicht. Später erneut versuchen.',
          _ => 'Challonge-Abruf fehlgeschlagen (${response.statusCode}).',
        });
      }
      return jsonDecode(
        await utf8.decoder
            .bind(response)
            .join()
            .timeout(const Duration(seconds: 30)),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Challonge nicht erreichbar oder ungültige Antwort.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<List<Map<String, dynamic>>> list(
    String apiKey,
    String community,
  ) async {
    if (apiKey.trim().isEmpty) return _publicReader.list(community);
    final uri = Uri.tryParse(community.trim());
    final subdomain = uri != null && uri.hasScheme
        ? uri.pathSegments.contains('communities')
              ? uri.pathSegments[uri.pathSegments.indexOf('communities') + 1]
              : uri.host.split('.').first
        : community.trim();
    final response = await _get('tournaments.json', apiKey, {
      'state': 'complete',
      if (subdomain.isNotEmpty) 'subdomain': subdomain,
    });
    return ChallongeTournament.unwrap(response as List, 'tournament');
  }

  Future<ChallongeTournament> tournament(
    String apiKey,
    String identifier,
  ) async {
    if (apiKey.trim().isEmpty) {
      return _publicReader.tournament(identifier);
    }
    final response = await _get(
      'tournaments/${Uri.encodeComponent(identifier)}.json',
      apiKey,
      {'include_participants': '1', 'include_matches': '1'},
    );
    return ChallongeTournament(
      Map<String, dynamic>.from(response['tournament'] as Map),
    );
  }

  static List<ChallongeTournament> decodeExport(String content) {
    final decoded = jsonDecode(content);
    final list = decoded is List ? decoded : [decoded];
    return ChallongeTournament.unwrap(
      list,
      'tournament',
    ).map(ChallongeTournament.new).toList();
  }
}
