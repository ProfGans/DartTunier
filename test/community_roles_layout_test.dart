import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/communities/presentation/community_roles_page.dart';
import 'package:dart_tournament_manager/features/communities/domain/community_permissions.dart';

void main() {
  testWidgets('Role editing survives resizing and large text', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: CommunityRoleEditor(
          grantable: CommunityPermissions(
            CommunityPermission.values.map((value) => value.key),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'Meine Turnierleitung');
    for (final size in [
      const Size(360, 800),
      const Size(800, 600),
      const Size(1440, 900),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(find.text('Meine Turnierleitung'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
