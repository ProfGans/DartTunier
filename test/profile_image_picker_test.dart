import 'dart:async';
import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:dart_tournament_manager/shared/images/profile_image_picker.dart';
import 'package:dart_tournament_manager/shared/images/profile_image_encoder.dart';
import 'package:dart_tournament_manager/shared/images/profile_avatar.dart';
import 'package:dart_tournament_manager/features/communities/presentation/community_profile_page.dart';
import 'package:dart_tournament_manager/features/communities/domain/community.dart';
import 'package:dart_tournament_manager/features/personal_profile/presentation/personal_profile_section.dart';
import 'package:dart_tournament_manager/features/personal_profile/domain/personal_profile.dart';
import 'community_profile_test.dart' show ProfileRepository;

class GrowingFile extends XFile {
  GrowingFile() : super('unused');
  @override
  Future<int> length() async => 1;
  @override
  Stream<Uint8List> openRead([int? start, int? end]) async* {
    yield Uint8List(ProfileImagePicker.maxBytes + 1);
  }
}

void main() {
  test('cancel and read limits are handled before encoding', () async {
    var encodes = 0;
    Future<String> encode(Uint8List bytes) async {
      encodes++;
      return 'encoded';
    }

    expect(
      await ProfileImagePicker(
        selectFile: () async => null,
        encode: encode,
      ).pick(),
      isNull,
    );
    for (final file in [
      XFile.fromData(Uint8List(ProfileImagePicker.maxBytes + 1)),
      GrowingFile(),
    ]) {
      await expectLater(
        ProfileImagePicker(selectFile: () async => file, encode: encode).pick(),
        throwsFormatException,
      );
    }
    expect(encodes, 0);
  });
  test(
    'JPEG and PNG produce small valid thumbnails; corrupt and oversized dimensions fail',
    () async {
      final source = img.Image(width: 600, height: 400);
      for (final bytes in [img.encodePng(source), img.encodeJpg(source)]) {
        final encoded = await ProfileImagePicker(
          selectFile: () async => XFile.fromData(bytes),
        ).pick();
        final decoded = img.decodeJpg(base64Decode(encoded!))!;
        expect(decoded.width, 256);
        expect(decoded.height, 256);
        expect(encoded.length, lessThanOrEqualTo(131072));
      }
      await expectLater(
        encodeProfileImage(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
      // PNG header with excessive dimensions, without allocating that image.
      final png = Uint8List.fromList(
        img.encodePng(img.Image(width: 1, height: 1)),
      );
      ByteData.sublistView(png).setUint32(16, 100000);
      ByteData.sublistView(png).setUint32(20, 100000);
      await expectLater(encodeProfileImage(png), throwsFormatException);
    },
  );
  test('filters cover native desktop, Android, iOS and web selectors', () {
    expect(
      ProfileImagePicker.types.extensions,
      containsAll(['jpg', 'png', 'webp']),
    );
    expect(
      ProfileImagePicker.types.mimeTypes,
      containsAll(['image/jpeg', 'image/png', 'image/webp']),
    );
    expect(
      ProfileImagePicker.types.uniformTypeIdentifiers,
      containsAll(['public.jpeg', 'public.png']),
    );
  });
  for (final community in [true, false]) {
    testWidgets(
      '${community ? 'community' : 'player'} stores the selected thumbnail',
      (tester) async {
        final bytes = img.encodePng(img.Image(width: 8, height: 8));
        final encoded = base64Encode(bytes);
        final picker = ProfileImagePicker(
          selectFile: () async => XFile.fromData(bytes),
          encode: (_) async => encoded,
        );
        final repository = ProfileRepository();
        PersonalProfile? saved;
        await tester.pumpWidget(
          MaterialApp(
            home: community
                ? CommunityProfilePage(
                    community: Community(
                      id: 'c',
                      name: 'Club',
                      description: '',
                      inviteCode: '',
                      ownerUserId: 'owner',
                      createdAt: DateTime(2026),
                    ),
                    repository: repository,
                    imagePicker: picker,
                  )
                : PersonalProfileEditor(
                    profile: const PersonalProfile(name: 'Anna'),
                    onSave: (value) async {
                      saved = value;
                    },
                    imagePicker: picker,
                  ),
          ),
        );
        await tester.tap(find.text('Profilbild auswählen'));
        await tester.pumpAndSettle();
        expect(find.text('Bild entfernen'), findsOneWidget);
        final save = find.text(
          community ? 'Änderungen speichern' : 'Profil speichern',
        );
        await tester.scrollUntilVisible(
          save,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(
          community ? repository.saved?.avatarBase64 : saved?.picture,
          encoded,
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '${community ? 'community' : 'player'} picker blocks repeats and recovers after errors/cancel',
      (tester) async {
        final pending = Completer<XFile?>();
        var calls = 0;
        final picker = ProfileImagePicker(
          selectFile: () {
            calls++;
            if (calls == 1) return pending.future;
            if (calls == 2) throw PlatformException(code: 'read_failed');
            return Future.value(null);
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: community
                ? CommunityProfilePage(
                    community: Community(
                      id: 'c',
                      name: 'Club',
                      description: '',
                      inviteCode: '',
                      ownerUserId: 'owner',
                      createdAt: DateTime(2026),
                    ),
                    repository: ProfileRepository(),
                    imagePicker: picker,
                  )
                : PersonalProfileEditor(
                    profile: const PersonalProfile(name: 'Anna'),
                    onSave: (_) async {},
                    imagePicker: picker,
                  ),
          ),
        );
        final button = find.widgetWithText(
          OutlinedButton,
          'Profilbild auswählen',
        );
        await tester.tap(button);
        await tester.pump();
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        expect(calls, 1);
        pending.complete(null);
        await tester.pumpAndSettle();
        expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(calls, 3);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '${community ? 'community' : 'player'} picker can finish after page disposal',
      (tester) async {
        final pending = Completer<XFile?>();
        final picker = ProfileImagePicker(selectFile: () => pending.future);
        await tester.pumpWidget(
          MaterialApp(
            home: community
                ? CommunityProfilePage(
                    community: Community(
                      id: 'c',
                      name: 'Club',
                      description: '',
                      inviteCode: '',
                      ownerUserId: 'owner',
                      createdAt: DateTime(2026),
                    ),
                    repository: ProfileRepository(),
                    imagePicker: picker,
                  )
                : PersonalProfileEditor(
                    profile: const PersonalProfile(name: 'Anna'),
                    onSave: (_) async {},
                    imagePicker: picker,
                  ),
          ),
        );
        await tester.tap(find.text('Profilbild auswählen'));
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        pending.completeError(PlatformException(code: 'cancelled'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('corrupt cached avatar falls back safely', (tester) async {
    for (final picture in [
      'not base64!',
      base64Encode([1, 2, 3]),
    ]) {
      await tester.pumpWidget(
        MaterialApp(home: ProfileAvatar(picture: picture)),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
