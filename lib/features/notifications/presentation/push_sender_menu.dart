import '../../../shared/widgets/sport_menu.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../data/app_push_repository.dart';
import 'push_sender_page.dart';

class PushSenderMenu extends StatefulWidget {
  const PushSenderMenu({super.key, this.repository});
  final AppPushRepository? repository;
  @override
  State<PushSenderMenu> createState() => _PushSenderMenuState();
}

class _PushSenderMenuState extends State<PushSenderMenu> {
  late final repository = widget.repository ?? AppPushRepository();
  StreamSubscription<dynamic>? auth;
  bool allowed = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    refresh();
    auth = repository.authChanges?.listen((_) => refresh());
  }

  Future<void> refresh() async {
    final current = ++generation;
    if (mounted) setState(() => allowed = false);
    final result = await repository.canSend();
    if (mounted && current == generation) setState(() => allowed = result);
  }

  @override
  void dispose() {
    auth?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !allowed
      ? const SizedBox.shrink()
      : SportMenuGroup(
          title: 'Nachrichten',
          actions: [
            SportMenuAction(
              icon: Icons.notifications_active_outlined,
              label: 'Push-Nachricht senden',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PushSenderPage(repository: repository),
                ),
              ),
            ),
          ],
        );
}
