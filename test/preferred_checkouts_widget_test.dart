import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:dart_tournament_manager/features/scorer/domain/fixed_checkouts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/personal_profile/data/personal_profile_repository.dart';
import 'package:dart_tournament_manager/features/personal_profile/domain/personal_profile.dart';
import 'package:dart_tournament_manager/features/scorer/domain/x01/x01_models.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/widgets/personalized_checkout_routes.dart';

class _Profiles extends PersonalProfileRepository {
  @override
  Future<PersonalProfile> load(String accountId, String defaultName) async =>
      const PersonalProfile(name: 'Anna', favoriteDouble: 'D16');
}

void main() {
  const previewFont = String.fromEnvironment('LAYOUT_PREVIEW_FONT');
  setUpAll(() async {
    if (previewFont.isNotEmpty) {
      final loader = FontLoader('Roboto')
        ..addFont(
          Future.value(
            ByteData.sublistView(await File(previewFont).readAsBytes()),
          ),
        );
      await loader.load();
    }
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('favorite applies only to own turn at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _Profiles();
      final previewKey = GlobalKey();
      Widget page(bool enabled) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: RepaintBoundary(
              key: previewKey,
              child: PersonalizedCheckoutRoutes(
                accountId: 'anna',
                repository: repository,
                enabled: enabled,
                score: 40,
                dartsLeft: 3,
                requirement: CheckoutRequirement.doubleOut,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(page(true));
      await tester.pumpAndSettle();
      expect(find.text('1.  8 → D16'), findsOneWidget);
      expect(find.text('Bevorzugtes Finish: D16'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (previewFont.isNotEmpty) {
        await tester.runAsync(() async {
          final boundary =
              previewKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final picture = await boundary.toImage();
          final bytes = await picture.toByteData(
            format: ui.ImageByteFormat.png,
          );
          final file = File(
            'build/layout_previews/preferred_checkout_${size.width.toInt()}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          picture.dispose();
        });
      }
      await tester.pumpWidget(page(false));
      await tester.pumpAndSettle();
      expect(
        find.text(
          '1.  ${FixedCheckouts.routes(40).first.map((d) => d.label).join(' → ')}',
        ),
        findsOneWidget,
      );
      expect(find.text('Bevorzugtes Finish: D16'), findsNothing);
      await tester.pumpWidget(page(true));
      await tester.pumpAndSettle();
      expect(find.text('1.  8 → D16'), findsOneWidget);
    });
  }
}
