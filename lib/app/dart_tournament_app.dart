import '../features/scorer/presentation/lobby/scorer_invitation_listener.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../tournament_workspace.dart';
import 'app_theme.dart';
import '../features/tournaments/application/tournament_sync_service.dart';
import 'navigation/community_link_listener.dart';
import '../features/communities/presentation/community_invitation_page.dart';
import '../features/devices/application/devices_controller.dart';
import '../features/devices/presentation/devices_scope.dart';
import '../features/devices/presentation/board_display_view.dart';
import '../features/devices/presentation/pairing_request_view.dart';

class DartTournamentApp extends StatefulWidget {
  const DartTournamentApp({super.key});

  @override
  State<DartTournamentApp> createState() => _DartTournamentAppState();
}

class _DartTournamentAppState extends State<DartTournamentApp> with WidgetsBindingObserver {
  final _tournamentSync = TournamentSyncService();
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final DevicesController _devices;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tournamentSync.start();
    _devices = DevicesController();
    _devices.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tournamentSync.dispose();
    _devices.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tournamentSync.synchronize();
  }

  @override
  Widget build(BuildContext context) {
    return DevicesScope(
      controller: _devices,
      child: CommunityLinkListener(
        onInvitation: (code) async {
          await _navigatorKey.currentState?.push(
            MaterialPageRoute<void>(
              builder: (_) => CommunityInvitationPage(
                code: code,
                createTournamentBuilder: (id, name) => TournamentCreationPage(
                  communityId: id,
                  communityName: name,
                ),
                runTournamentBuilder: (tournament) =>
                    TournamentRunPage(tournament: tournament),
              ),
            ),
          );
        },
        child: ScorerInvitationListener(
          navigatorKey: _navigatorKey,
          child: MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'Dart Turnierverwaltung',
            builder: (context, child) => AnimatedBuilder(
              animation: _devices,
              builder: (context, _) => Stack(
                children: [
                  child ?? const SizedBox(),
                  if (_devices.settings?.enabled == true &&
                      _devices.receiver.display != null)
                    Positioned.fill(
                      child: Offstage(offstage: !_devices.showDisplay,
                        child: BoardDisplayView(controller: _devices)),
                    ),
                  if (_devices.receiver.pairingName != null)
                    Positioned.fill(
                      child: PairingRequestView(receiver: _devices.receiver),
                    ),
                ],
              ),
            ),
            scrollBehavior: const DartTournamentScrollBehavior(),
            theme: buildDartTournamentTheme(),
            home: const HomePage(),
          ),
        ),
      ),
    );
  }
}

class DartTournamentScrollBehavior extends MaterialScrollBehavior {
  const DartTournamentScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
