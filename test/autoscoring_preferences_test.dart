import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:dart_tournament_manager/features/autoscoring/data/autoscoring_preferences.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/widgets/scorer_camera_panel.dart';
import 'package:dart_tournament_manager/features/autoscoring/presentation/widgets/autoscoring_preference_tile.dart';
import 'package:dart_tournament_manager/features/scorer/presentation/scorer_match_page.dart';
import 'package:dart_tournament_manager/features/scorer/domain/scorer_settings.dart';

class _Cameras extends CameraPlatform {
  _Cameras(this.count);
  final int count;
  @override
  Future<List<CameraDescription>> availableCameras() async => [
    for (var i = 0; i < count; i++)
      CameraDescription(
        name: 'USB $i',
        lensDirection: CameraLensDirection.external,
        sensorOrientation: 0,
      ),
  ];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('Switch persists across recreating settings', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AutoscoringPreferenceTile())),
    );
    await tester.pumpAndSettle();
    expect(await AutoscoringPreferences().load(), isFalse);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(await AutoscoringPreferences().load(), isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AutoscoringPreferenceTile())),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
  });
  for (final enabled in [false, true]) {
    for (final count in [0, 2, 3]) {
      testWidgets('Auto start enabled=$enabled cameras=$count', (tester) async {
        final previous = CameraPlatform.instance;
        CameraPlatform.instance = _Cameras(count);
        addTearDown(() => CameraPlatform.instance = previous);
        await AutoscoringPreferences().save(enabled);
        await tester.pumpWidget(
          MaterialApp(
            home: ScorerMatchPage(
              settings: ScorerSettings(
                participants: const [
                  ScorerParticipant('A'),
                  ScorerParticipant('B'),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(ScorerCameraPanel),
          enabled && count >= 3 ? findsOneWidget : findsNothing,
        );
        if (enabled && count >= 3) {
          tester
              .widget<ScorerCameraPanel>(find.byType(ScorerCameraPanel))
              .onClose();
          await tester.pumpAndSettle();
          expect(find.byType(ScorerCameraPanel), findsNothing);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
