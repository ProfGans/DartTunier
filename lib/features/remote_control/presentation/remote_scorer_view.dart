import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dart_tournament_manager/shared/widgets/adaptive_content.dart';
import '../../scorer/data/scorer_draft_storage.dart';
import '../../scorer/domain/scorer_opponents.dart';
import '../../scorer/presentation/scorer_match_page.dart';
import '../../scorer/presentation/scorer_setup_page.dart';
import '../application/remote_client_controller.dart';

/// Same responsive scorer widgets, driven by a host-owned match rather than pixels.
class RemoteScorerView extends StatelessWidget {
  const RemoteScorerView({super.key, required this.client});
  final RemoteClientController client;

  Future<void> _start(BuildContext context, ScorerOpponents opponents) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ScorerSetupPage(
          opponents: opponents,
          remoteStart: (settings) => client.scorer.command(
            'start',
            values: {'settings': ScorerDraftStorage.encodeSettings(settings)},
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: client.scorer,
    builder: (context, _) {
      final remote = client.scorer;
      final controller = remote.controller;
      return Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    remote.pending
                        ? 'Eingabe wird am Hauptgerät übernommen …'
                        : remote.connected
                        ? 'Scorer mit Hauptgerät synchronisiert'
                        : 'Verbindung nicht bestätigt – bitte neu verbinden',
                  ),
                  TextButton.icon(
                    onPressed: () => unawaited(client.disconnect()),
                    icon: const Icon(Icons.link_off),
                    label: const Text('Trennen'),
                  ),
                  if (remote.error != null) Text(remote.error!),
                ],
              ),
            ),
          ),
          Expanded(
            child: controller == null
                ? AdaptiveContentList(
                    children: [
                      const Text(
                        'Am Hauptgerät ist noch keine Scorer-Partie geöffnet.',
                      ),
                      const SizedBox(height: 16),
                      if (remote.state == null) const LinearProgressIndicator(),
                      if (remote.state?['canStart'] == true)
                        for (final opponents in ScorerOpponents.values)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: FilledButton(
                              onPressed: remote.ready
                                  ? () => _start(context, opponents)
                                  : null,
                              child: Text(
                                '${opponents.label} am Hauptgerät starten',
                              ),
                            ),
                          ),
                      const Text(
                        'Du kannst die Partie auch am Hauptgerät öffnen. Der Scorer erscheint dann automatisch hier.',
                      ),
                    ],
                  )
                : ScorerMatchPage(
                    key: ValueKey(remote.sessionId),
                    settings: controller.settings,
                    remote: remote,
                    onExit: () => unawaited(client.disconnect()),
                  ),
          ),
        ],
      );
    },
  );
}
