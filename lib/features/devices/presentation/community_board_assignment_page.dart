import 'package:flutter/material.dart';
import '../../../../tournament_workspace.dart' show TournamentRunPage;
import '../../communities/data/community_access_repository.dart';
import '../../tournaments/domain/tournament_models.dart';
import '../../communities/domain/community_permissions.dart';
import '../../communities/presentation/widgets/community_permission_gate.dart';
import '../application/board_device_dispatcher.dart';
import 'board_device_assignment_page.dart';
import 'devices_scope.dart';

class CommunityBoardAssignmentPage extends StatelessWidget {
  const CommunityBoardAssignmentPage({super.key, required this.tournament});
  final CreatedTournament tournament;
  @override
  Widget build(BuildContext context) => CommunityPermissionGate(
    communityId: tournament.communityId,
    permission: CommunityPermission.assignDevices,
    builder: (_) => FutureBuilder<CommunityPermissions>(
      future: CommunityAccessRepository().permissions(tournament.communityId!),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(appBar: AppBar(title: const Text('Geräte zuteilen')),
          body: const Center(child: Text('Rechte konnten nicht geladen werden. Bitte die Ansicht erneut öffnen.')));
        }
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (snapshot.data!.allows(CommunityPermission.leadTournaments)) {
          return TournamentRunPage(tournament: tournament, openDevicesOnStart: true);
        }
        return _AssignmentSession(tournament: tournament);
      },
    ),
  );
}

class _AssignmentSession extends StatefulWidget {
  const _AssignmentSession({required this.tournament});
  final CreatedTournament tournament;
  @override
  State<_AssignmentSession> createState() => _AssignmentSessionState();
}

class _AssignmentSessionState extends State<_AssignmentSession> {
  BoardDeviceDispatcher? _dispatcher;
  bool _started = false;
  String? _error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final devices = DevicesScope.maybeOf(context);
    if (devices == null) {
      _error = 'Gerätefunktion ist nicht verfügbar.';
      return;
    }
    _dispatcher = BoardDeviceDispatcher(
      devices: devices,
      tournament: widget.tournament,
      activeStage: () => widget.tournament.activeStageIndex,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await _dispatcher!.start();
      } catch (_) {
        if (mounted) {
          setState(
            () => _error =
                'Gerätezuordnung nicht möglich. Rechte und Verbindung prüfen.',
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _dispatcher?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _error != null
      ? Scaffold(
          appBar: AppBar(title: const Text('Geräte zuteilen')),
          body: Center(child: Text(_error!)),
        )
      : BoardDeviceAssignmentPage(dispatcher: _dispatcher!);
}
