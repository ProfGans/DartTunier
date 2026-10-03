import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_tournament_manager/features/personal_profile/data/personal_profile_repository.dart';
import 'package:dart_tournament_manager/features/personal_profile/domain/personal_profile.dart';
import 'package:dart_tournament_manager/features/personal_profile/presentation/personal_profile_section.dart';

void main() {
  test('profile persists per account and validates Spotify hosts', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = PersonalProfileRepository();
    const profile = PersonalProfile(
      name: 'Anna',
      nationality: 'Deutschland',
      song: 'Song',
      spotify: 'https://open.spotify.com/track/123',
      favoritePlayer: 'Spieler',
      favoriteDouble: 'D20',
    );
    await repository.save('a', profile);
    expect((await repository.load('a', 'Default')).toJson(), profile.toJson());
    expect((await repository.load('b', 'Other')).name, 'Other');
    expect(
      PersonalProfile.validSpotify(
        'https://open.spotify.com.evil.com/track/123',
      ),
      isFalse,
    );
    expect(
      PersonalProfile.validSpotify('https://open.spotify.com/playlist/123'),
      isFalse,
    );
    expect(PersonalProfile.validSpotify(profile.spotify), isTrue);
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('profile editor $size scale $scale', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        PersonalProfile? saved;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: PersonalProfileEditor(
                profile: const PersonalProfile(name: 'Anna'),
                onSave: (value) async {
                  saved = value;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('personal-profile-field-0')),
          200,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.enterText(
          find.byKey(const ValueKey('personal-profile-field-0')),
          'Neuer Name',
        );
        final setupField = find.byKey(const ValueKey('dart-setup-field-0'));
        await tester.scrollUntilVisible(
          setupField,
          250,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.enterText(setupField, 'Meine Darts');
        await tester.scrollUntilVisible(
          find.text('Profil speichern'),
          300,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('Profil speichern')),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        for (
          var attempt = 0;
          attempt < 5 &&
              find.text('Profil speichern').hitTestable().evaluate().isEmpty;
          attempt++
        ) {
          await tester.drag(find.byType(ListView), const Offset(0, -120));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Profil speichern'));
        await tester.pumpAndSettle();
        expect(saved?.name, 'Neuer Name');
        expect(saved?.dartSetup.barrel, 'Meine Darts');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
