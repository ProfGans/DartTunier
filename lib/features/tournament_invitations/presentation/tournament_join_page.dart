import 'package:flutter/material.dart';
import 'dart:async';
import '../domain/invitation_request_id.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../../accounts/presentation/widgets/account_menu_card.dart';
import '../data/tournament_invitation_repository.dart';

class TournamentJoinPage extends StatefulWidget {
  const TournamentJoinPage({super.key, required this.token, this.repository});
  final String token;
  final TournamentInvitationRepository? repository;
  @override
  State<TournamentJoinPage> createState() => _JoinState();
}

class _JoinState extends State<TournamentJoinPage> {
  late final repository = widget.repository ?? TournamentInvitationRepository();
  final name = TextEditingController();
  final request = invitationRequestId();
  late final info = repository.info(widget.token);
  bool busy = false, done = false;
  String? error;
  StreamSubscription? authSubscription;
  @override
  void initState() {
    super.initState();
    authSubscription = repository.client.auth.onAuthStateChange.listen((_) {
      if (mounted) setState(() {});
    });
  }
  @override
  void dispose() {
    name.dispose();
    authSubscription?.cancel();
    super.dispose();
  }

  Future<void> join() async {
    if (repository.client.auth.currentUser == null && name.text.trim().isEmpty) {
      setState(() => error = 'Bitte deinen Spielernamen eingeben.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repository.join(widget.token, name.text.trim(), request);
      if (mounted) setState(() => done = true);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Anmeldung fehlgeschlagen. Verbindung und Einladung prüfen.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Turnier beitreten')),
    body: AdaptiveContentList(
      children: [
        FutureBuilder<Map<String, dynamic>?>(
          future: info,
          builder: (_, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError || snapshot.data == null) {
              return const Text('Einladung nicht verfügbar oder abgelaufen.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.data!['title'] as String,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (done)
                  const Text(
                    'Anmeldung gesendet. Die Turnierleitung ordnet dich einem Spieler zu.',
                  )
                else ...[
                  const Text(
                    'Mit Account anmelden, um deine Anmeldung mit deinem Profil zu verknüpfen. Eine Gastanmeldung ist ebenfalls möglich.',
                  ),
                  const AccountMenuCard(),
                  if (repository.client.auth.currentUser != null)
                    const Text('Für die Anmeldung wird automatisch dein Account-Name verwendet.')
                  else TextField(
                    controller: name,
                    maxLength: 80,
                    enabled: !busy,
                    decoration: const InputDecoration(labelText: 'Spielername'),
                  ),
                  if (error != null) Text(error!),
                  FilledButton(
                    onPressed: busy ? null : join,
                    child: Text(
                      busy ? 'Wird gesendet …' : 'Am Turnier anmelden',
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    ),
  );
}
