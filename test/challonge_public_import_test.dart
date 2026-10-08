import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/communities/data/challonge_public_reader.dart';
import 'package:dart_tournament_manager/features/communities/data/challonge_client.dart';
import 'challonge_import_test.dart' show challongeFixture;

void main() {
  test(
    'keyless import reads complete embedded records without executing scripts',
    () async {
      final urls = <Uri>[];
      final reader = ChallongePublicReader(
        readDocument: (uri) async {
          urls.add(uri);
          return '<html><script>window.source = ${jsonEncode({'tournament': challongeFixture()})}; throw new Error("never executed");</script></html>';
        },
      );
      final client = ChallongeClient(publicReader: reader);
      final t = await client.tournament(
        '',
        'https://club.challonge.com/old_tournament',
      );
      expect(
        urls.single.toString(),
        'https://club.challonge.com/old_tournament',
      );
      expect(urls.single.queryParameters.containsKey('api_key'), isFalse);
      final imported = t.convert('community', {'1': 'a', '2': 'b', '3': 'c'});
      expect(
        imported.importedArchive!.participants.map((p) => p['finalRank']),
        [1, 2, 2],
      );
      expect(imported.importedArchive!.matches.length, 3);
    },
  );
  test(
    'public community lists deduplicated tournament links and excludes navigation',
    () async {
      final reader = ChallongePublicReader(
        readDocument: (uri) async => '''
      <a href="/de/communities/club">Community</a>
      <a href="/de/login">Anmelden</a>
      <a href="/de/old_tournament"><strong>Altes Turnier &amp; Finale</strong></a>
      <a href="/de/old_tournament">Altes Turnier</a>
      <a href="https://club.challonge.com/final">Vereinsfinale</a>
      <a href="https://external.test/final">Fremde Seite</a>
    ''',
      );
      final list = await ChallongeClient(
        publicReader: reader,
      ).list('', 'https://challonge.com/de/communities/club/tournaments');
      expect(list.length, 2);
      expect(list.map((t) => t['id']), [
        'https://challonge.com/de/old_tournament',
        'https://club.challonge.com/final',
      ]);
    },
  );
  test(
    'public reader rejects login pages and text-only results rather than inventing data',
    () {
      for (final page in [
        '<html><h1>Just a moment...</h1></html>',
        '<html><table><tr><td>1. Anna</td><td>3-1</td></tr></table></html>',
        '<script>window.user={"id":1,"name":"Anna"};</script>',
      ]) {
        expect(
          () => ChallongePublicReader.decodeDocument(page),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'structured HTML keeps strings with braces and supports multiple records',
    () {
      final a = challongeFixture()..['name'] = 'Turnier "{Finale}"';
      final page =
          '<script type="application/json">${jsonEncode([
            {'tournament': a},
            {'tournament': challongeFixture(id: 8)},
          ])}</script>';
      final sources = ChallongePublicReader.decodeDocument(page);
      expect(sources.map((t) => t.id), ['7', '8']);
      expect(sources.first.title, 'Turnier "{Finale}"');
    },
  );
  test('incomplete public structured records remain rejected', () {
    final incomplete = challongeFixture()..remove('matches');
    expect(
      () => ChallongePublicReader.decodeDocument(
        '<script>${jsonEncode(incomplete)}</script>',
      ),
      throwsFormatException,
    );
    final ongoing = challongeFixture()..['state'] = 'underway';
    expect(
      () => ChallongePublicReader.decodeDocument(
        '<script>${jsonEncode(ongoing)}</script>',
      ),
      throwsFormatException,
    );
  });
  test('keyless reader accepts only public HTTPS Challonge hosts', () {
    for (final url in [
      'http://challonge.com/old',
      'https://challonge.com.evil.test/old',
      'https://name:secret@challonge.com/old',
      'file:///old',
      'https://challonge.com:444/old',
    ]) {
      expect(
        () => ChallongePublicReader.validateUrl(url),
        throwsFormatException,
      );
    }
    expect(
      ChallongePublicReader.validateUrl('https://challonge.com/de/old').host,
      'challonge.com',
    );
  });
}
