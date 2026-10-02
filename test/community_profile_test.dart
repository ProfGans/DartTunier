import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:dart_tournament_manager/features/communities/application/community_avatar_encoder.dart';
import 'package:dart_tournament_manager/features/communities/domain/community.dart';
import 'package:dart_tournament_manager/features/communities/presentation/community_profile_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dart_tournament_manager/features/communities/data/supabase_community_repository.dart';

class ProfileRepository extends SupabaseCommunityRepository {
  ProfileRepository()
    : super(
        client: SupabaseClient(
          'https://example.test',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  Community? saved;
  @override
  Future<Community> updateProfile(
    Community community, {
    required String name,
    required String bio,
    required String? avatarBase64,
  }) async {
    return saved = Community(
      id: community.id,
      name: name.trim(),
      description: bio.trim(),
      inviteCode: '',
      ownerUserId: 'owner',
      createdAt: community.createdAt,
      avatarBase64: avatarBase64,
    );
  }
}

void main() {
  test(
    'avatar is resized and malformed or oversized files are rejected',
    () async {
      final source = img.Image(width: 600, height: 400);
      final result = await encodeCommunityAvatar(
        Uint8List.fromList(img.encodePng(source)),
      );
      final decoded = img.decodeJpg(base64Decode(result))!;
      expect(decoded.width, 256);
      expect(decoded.height, 256);
      expect(result.length, lessThanOrEqualTo(131072));
      await expectLater(
        encodeCommunityAvatar(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
      await expectLater(
        encodeCommunityAvatar(Uint8List(5 * 1024 * 1024 + 1)),
        throwsFormatException,
      );
    },
  );
  testWidgets(
    'community profile preserves edits across sizes and saves name and bio',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = ProfileRepository();
      final community = Community(
        id: 'c',
        name: 'Club',
        description: 'Alte Bio',
        inviteCode: '',
        ownerUserId: 'owner',
        createdAt: DateTime(2026),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: CommunityProfilePage(
            community: community,
            repository: repository,
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        'Neuer Dartclub',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'Unsere neue Community-Bio',
      );
      for (final size in [
        const Size(360, 800),
        const Size(800, 600),
        const Size(1440, 900),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(find.text('Neuer Dartclub'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.ensureVisible(find.text('Änderungen speichern'));
      await tester.tap(find.text('Änderungen speichern'));
      await tester.pumpAndSettle();
      expect(repository.saved!.name, 'Neuer Dartclub');
      expect(repository.saved!.description, 'Unsere neue Community-Bio');
    },
  );
}
