import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dart_tournament_manager/features/devices/data/community_device_repository.dart';
import 'package:dart_tournament_manager/features/devices/domain/app_device.dart';
import 'package:dart_tournament_manager/features/devices/presentation/device_community_section.dart';

const device = AppDevice(
  id: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  name: 'Board 1',
  platform: 'windows',
);

class FakeGroups extends CommunityDeviceRepository {
  bool joined = false;
  String? invitation;
  @override
  Future<List<Map<String, dynamic>>> groups(String deviceId) async => joined
      ? [
          {'community_id': 'group', 'community_name': 'Dartclub'},
        ]
      : [];
  @override
  Future<void> join(AppDevice device, String invitation) async {
    this.invitation = invitation;
    joined = true;
  }

  @override
  Future<void> leave(String communityId, String deviceId) async {
    joined = false;
  }
}

void main() {
  test('group operations require an authenticated account', () async {
    final repository = CommunityDeviceRepository();
    await expectLater(repository.join(device, 'ABCD1234'), throwsStateError);
    await expectLater(repository.groups(device.id), throwsStateError);
    await expectLater(repository.devices('group'), throwsStateError);
    await expectLater(repository.leave('group', device.id), throwsStateError);
  });
  testWidgets('device joins with validated invitation and leaves group', (
    tester,
  ) async {
    final repository = FakeGroups();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeviceCommunitySection(device: device, repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Als Gerät einer Gruppe beitreten'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'bad');
    await tester.tap(find.text('Als Gerät beitreten'));
    await tester.pumpAndSettle();
    expect(repository.joined, isFalse);
    await tester.enterText(
      find.byType(TextFormField),
      'dartturnier://community/join?code=ABCD1234',
    );
    await tester.tap(find.text('Als Gerät beitreten'));
    await tester.pumpAndSettle();
    expect(find.text('Dartclub'), findsOneWidget);
    expect(find.text('Mitglied als Gerät'), findsOneWidget);
    await tester.tap(find.byTooltip('Gruppe als Gerät verlassen'));
    await tester.pumpAndSettle();
    expect(repository.joined, isFalse);
    expect(find.text('Dartclub'), findsNothing);
  });
}
