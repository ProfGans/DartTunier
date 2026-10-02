import 'dart:async';
import 'package:flutter/material.dart';
import '../data/league_invitation_repository.dart';

class LeagueInvitationListener extends StatefulWidget {
  const LeagueInvitationListener({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.repository,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final LeagueInvitationRepository? repository;
  @override
  State<LeagueInvitationListener> createState() =>
      _LeagueInvitationListenerState();
}

class _LeagueInvitationListenerState extends State<LeagueInvitationListener>
    with WidgetsBindingObserver {
  late final repo = widget.repository ?? LeagueInvitationRepository();
  Timer? timer;
  bool busy = false, active = true;
  final seen = <String>{};
  String? account;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 9), (_) => poll());
    WidgetsBinding.instance.addPostFrameCallback((_) => poll());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (active) poll();
  }

  Future<void> poll() async {
    if (busy || !active || !mounted) return;
    final user = repo.userId;
    if (account != user) {
      account = user;
      seen.clear();
    }
    if (user == null) return;
    busy = true;
    try {
      for (final row in await repo.inbox()) {
        if (!mounted || !active || repo.userId != user) return;
        final id = row['id'] as String;
        if (seen.contains(id)) continue;
        final context = widget.navigatorKey.currentState?.overlay?.context;
        if (context == null || !context.mounted) return;
        final choice = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Einladung zum Ligaspiel'),
            content: SingleChildScrollView(
              child: Text(
                '${row['title']}\nDu bist für die ${row['team'] == 0 ? 'Heim' : 'Gast'}mannschaft eingeladen. Erst nach deiner Annahme wirst du in die Aufstellung übernommen.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Ablehnen'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Annehmen'),
              ),
            ],
          ),
        );
        if (!mounted || repo.userId != user) return;
        if (choice == null) {
          seen.add(id);
          return;
        }
        try {
          await repo.respond(id, choice);
          seen.add(id);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
              const SnackBar(
                content: Text(
                  'Antwort konnte nicht gespeichert werden. Die Einladung wird erneut angezeigt.',
                ),
              ),
            );
          }
        }
        break;
      }
    } catch (_) {
      /* Offline or backend migration pending: retry later. */
    } finally {
      busy = false;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
