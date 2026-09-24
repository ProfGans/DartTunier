import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/app/navigation/community_link_listener.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_invitation.dart';

void main() {
  test(
    'invitation links round-trip and reject unrelated or malformed links',
    () {
      final link = CommunityInvitation.link(' abcdef23 ');
      expect(link, 'dartturnier://community/join?code=ABCDEF23');
      expect(CommunityInvitation.parseInput(link), 'ABCDEF23');
      expect(CommunityInvitation.parseInput('abcdef23'), 'ABCDEF23');
      for (final input in [
        'https://other.test/community?code=ABCDEF23',
        'dartturnier://community/join?code=short',
        'dartturnier://community/join?code=ABCDEF23&code=ABCDEFGH',
        'dartturnier://other/join?code=ABCDEF23',
        'dartturnier://community/delete?code=ABCDEF23',
        'dartturnier://user@community/join?code=ABCDEF23',
        'dartturnier://community:123/join?code=ABCDEF23',
      ]) {
        expect(CommunityInvitation.parseInput(input), isNull, reason: input);
      }
    },
  );

  testWidgets('cold and warm links open once while invitation remains open', (
    tester,
  ) async {
    final stream = StreamController<Uri>.broadcast();
    final uri = Uri.parse(CommunityInvitation.link('ABCDEF23'));
    final opened = <String>[];
    var close = Completer<void>();
    await tester.pumpWidget(
      CommunityLinkListener(
        links: stream.stream,
        initialLink: Future.value(uri),
        onInvitation: (code) {
          opened.add(code);
          return close.future;
        },
        child: const MaterialApp(home: SizedBox()),
      ),
    );
    await tester.pump();
    stream.add(uri);
    await tester.pumpAndSettle();
    expect(opened, ['ABCDEF23']);
    close.complete();
    await tester.pump();
    close = Completer<void>();
    stream.add(uri);
    await tester.pumpAndSettle();
    expect(opened, ['ABCDEF23', 'ABCDEF23']);
    close.complete();
    await tester.pumpWidget(const SizedBox());
    await stream.close();
  });
}
