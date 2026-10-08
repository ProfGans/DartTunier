import 'dart:convert';
import 'dart:io';
import '../domain/challonge_tournament.dart';
import 'challonge_public_document.dart';

/// Reads public documents only. No login cookies, API keys or script execution.
class ChallongePublicReader {
  ChallongePublicReader({this.readDocument});
  final Future<String> Function(Uri uri)? readDocument;

  static Uri validateUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        (uri.host != 'challonge.com' && !uri.host.endsWith('.challonge.com')) ||
        (uri.hasPort && uri.port != 443)) {
      throw const FormatException(
        'Einen öffentlichen HTTPS-Link von Challonge eingeben.',
      );
    }
    return uri.removeFragment();
  }

  Future<String> _read(Uri uri) async {
    if (readDocument != null) return readDocument!(uri);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      var target = uri;
      for (var hop = 0; hop < 4; hop++) {
        final request = await client.getUrl(target);
        request.followRedirects = false;
        final response = await request.close().timeout(
          const Duration(seconds: 30),
        );
        if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location == null) break;
          target = validateUrl(target.resolve(location).toString());
          await response.drain<void>();
          continue;
        }
        if (response.statusCode != 200) {
          throw FormatException(
            response.statusCode == 403 || response.statusCode == 401
                ? 'Challonge blockiert den öffentlichen Abruf oder verlangt eine Anmeldung. Eine vollständige gespeicherte JSON-/HTML-Turnierdatei öffnen.'
                : 'Öffentlicher Challonge-Abruf fehlgeschlagen (${response.statusCode}).',
          );
        }
        return await utf8.decoder
            .bind(response)
            .join()
            .timeout(const Duration(seconds: 30));
      }
      throw const FormatException('Challonge leitet zu häufig weiter.');
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Die öffentliche Challonge-Seite ist nicht erreichbar.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<ChallongeTournament> tournament(String link) async {
    final uri = validateUrl(link);
    final content = await _read(uri);
    final store = ChallongePublicDocument.store(content);
    if (store != null) {
      final standings = ChallongePublicDocument.standingsLink(content);
      final ranks = standings == null
          ? content
          : await _read(validateUrl(uri.resolve(standings).toString()));
      return ChallongePublicDocument.convert(content, ranks, store, uri);
    }
    final tournaments = decodeDocument(content);
    if (tournaments.length != 1) {
      throw const FormatException('Bitte einen einzelnen Turnierlink öffnen.');
    }
    return tournaments.single;
  }

  Future<List<Map<String, dynamic>>> list(String link) async {
    final uri = validateUrl(link);
    final content = await _read(uri);
    final links = <String, Map<String, dynamic>>{};
    final anchors = RegExp(
      r'''<a\b[^>]*\bhref\s*=\s*["']([^"']+)["'][^>]*>([\s\S]*?)</a\s*>''',
      caseSensitive: false,
    );
    const reserved = {
      'communities',
      'users',
      'user',
      'login',
      'signup',
      'sign_up',
      'tournaments',
      'events',
      'settings',
      'features',
      'pricing',
      'contact',
      'about',
      'privacy',
      'terms',
      'dashboard',
      'oauth',
      'api',
      'search',
      'logout',
      'help',
      'connect',
      'partners',
      'organizedplay',
      'terms_of_service',
      'privacy_policy',
    };
    for (final anchor in anchors.allMatches(content)) {
      Uri target;
      try {
        target = validateUrl(uri.resolve(_text(anchor[1]!)).toString());
      } on FormatException {
        continue;
      }
      final parts = target.pathSegments.where((p) => p.isNotEmpty).toList();
      if (parts.isNotEmpty &&
          [
            'de',
            'en',
            'fr',
            'es',
            'pt',
            'ja',
            'it',
            'nl',
            'sv',
            'ko',
            'ru',
            'zh_CN',
            'zh_TW',
          ].contains(parts.first)) {
        parts.removeAt(0);
      }
      if (parts.length != 1 ||
          reserved.contains(parts.single) ||
          target.queryParameters.isNotEmpty) {
        continue;
      }
      final name = _text(anchor[2]!).trim();
      if (name.isEmpty ||
          [
            'Challonge',
            'Anmelden',
            'Registrieren',
            'Log in',
            'Sign up',
          ].contains(name)) {
        continue;
      }
      final url = target.toString();
      links[url] = {'id': url, 'name': name, 'public_url': url};
    }
    if (links.isEmpty) {
      throw const FormatException(
        'Keine öffentlichen Turnierlinks gefunden. Einzelne Turnierlinks eingeben oder gespeicherte Turnierdateien öffnen.',
      );
    }
    return links.values.toList();
  }

  static String _text(String html) => html
      .replaceAll(RegExp('<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ');

  /// Only complete structured records can be imported. Text tables and bracket
  /// drawings do not establish all participants, results and official ranks.
  static List<ChallongeTournament> decodeDocument(String content) {
    final records = <String, ChallongeTournament>{};
    void visit(dynamic node) {
      if (node is List) {
        for (final item in node) {
          visit(item);
        }
        return;
      }
      if (node is! Map) return;
      if (node['id'] != null &&
          node['participants'] is List &&
          node['matches'] is List) {
        final tournament = ChallongeTournament(Map<String, dynamic>.from(node));
        records[tournament.id] = tournament;
        return;
      }
      for (final child in node.values) {
        visit(child);
      }
    }

    try {
      visit(jsonDecode(content));
    } on FormatException {
      if (!content.trimLeft().startsWith('<')) rethrow;
    }
    if (records.isEmpty) {
      final scripts = RegExp(
        r'<script\b[^>]*>([\s\S]*?)</script\s*>',
        caseSensitive: false,
      );
      for (final script in scripts.allMatches(content)) {
        final source = script[1]!;
        for (var start = 0; start < source.length; start++) {
          if (source[start] != '{' && source[start] != '[') continue;
          final end = _jsonEnd(source, start);
          if (end == null) continue;
          dynamic decoded;
          try {
            decoded = jsonDecode(source.substring(start, end));
          } on FormatException {
            continue;
          }
          visit(decoded);
          start = end - 1;
        }
      }
    }
    if (records.isEmpty) {
      throw const FormatException(
        'Die Seite enthält keine vollständigen strukturierten Turnierdaten mit Teilnehmern und Spielen. Nur sichtbare Tabellen reichen für einen verlässlichen Import nicht aus. Eine vollständige JSON-/HTML-Turnierdatei öffnen.',
      );
    }
    return records.values.toList();
  }

  static int? _jsonEnd(String text, int start) {
    final stack = <String>[];
    var quoted = false, escaped = false;
    for (var i = start; i < text.length; i++) {
      final c = text[i];
      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (c == '\\') {
          escaped = true;
        } else if (c == '"') {
          quoted = false;
        }
        continue;
      }
      if (c == '"') {
        quoted = true;
        continue;
      }
      if (c == '{' || c == '[') {
        stack.add(c);
      }
      if (c == '}' || c == ']') {
        if (stack.isEmpty ||
            (c == '}' && stack.last != '{') ||
            (c == ']' && stack.last != '[')) {
          return null;
        }
        stack.removeLast();
        if (stack.isEmpty) return i + 1;
      }
    }
    return null;
  }
}
