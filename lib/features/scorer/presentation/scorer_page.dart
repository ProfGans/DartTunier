import 'package:flutter/material.dart';
import '../../autoscoring/presentation/autoscoring_page.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../../accounts/domain/account_user.dart';
import '../data/bot_settings_storage.dart';
import '../data/scorer_draft_storage.dart';
import '../data/repositories/checkout_route_repository.dart';
import '../application/scorer_controller.dart';
import 'scorer_match_page.dart';
import '../domain/scorer_opponents.dart';
import 'scorer_setup_page.dart';
import 'checkout_page.dart';
import 'lobby/scorer_join_page.dart';

class ScorerPage extends StatelessWidget {
  const ScorerPage({super.key, this.botStorage, this.account});
  final AccountUser? account;
  final BotSettingsStorage? botStorage;

  Future<void> _resume(BuildContext context) async {
    try {
      final draft = await ScorerDraftStorage().load(account?.id);
      if (!context.mounted) return;
      if (draft == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Es ist noch kein Spiel zwischengespeichert.'),
          ),
        );
        return;
      }
      final settings = ScorerDraftStorage.decodeSettings(
        draft['settings'] as Map<String, dynamic>,
      );
      // Validate before opening a route so damaged saves remain recoverable.
      final check = ScorerController(settings);
      try {
        check.restoreActions(draft['actions'] as List);
      } finally {
        check.dispose();
      }
      if (settings.participants.any((p) => p.bot != null)) {
        await CheckoutRouteRepository.instance.initialize();
      }
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ScorerMatchPage(
            settings: settings,
            draft: draft,
            accountId: account?.id,
            profilePlayerIndex: draft['profilePlayerIndex'] as int?,
          ),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Das gespeicherte Spiel konnte nicht geladen werden.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scorer')),
    body: AdaptiveContentList(
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Gespeichertes Spiel fortsetzen'),
            subtitle: const Text(
              'Den zuletzt zwischengespeicherten Spielstand öffnen',
            ),
            onTap: () => _resume(context),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Gegen wen möchtest du spielen?',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        AdaptiveTileLayout(
          children: [
            for (final mode in ScorerOpponents.values)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(switch (mode) {
                        ScorerOpponents.players => Icons.people_outline,
                        ScorerOpponents.bots => Icons.smart_toy_outlined,
                        ScorerOpponents.mixed => Icons.groups_outlined,
                      }),
                      const SizedBox(height: 12),
                      Text(
                        mode.label,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(switch (mode) {
                        ScorerOpponents.players =>
                          'Zwei oder mehr Spieler, mit Gastnamen oder eigenen Konten.',
                        ScorerOpponents.bots =>
                          'Spiele gegen einen oder mehrere Bots.',
                        ScorerOpponents.mixed =>
                          'Gemeinsam mit weiteren Spielern und Bots spielen.',
                      }),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ScorerSetupPage(
                              opponents: mode,
                              account: account,
                              botStorage: botStorage,
                            ),
                          ),
                        ),
                        child: Text(switch (mode) {
                          ScorerOpponents.players => 'Gegen Spieler spielen',
                          ScorerOpponents.bots => 'Gegen Bot spielen',
                          ScorerOpponents.mixed => 'Gemischtes Spiel',
                        }),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(Icons.videocam_outlined),
            title: const Text('Autoscorer · drei Kameras'),
            subtitle: const Text(
              'Windows-Prototyp: Kalibrierung und Treffererkennung',
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AutoscoringPage()),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ScorerJoinPage()),
          ),
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Spiel beitreten · QR-Code / Code'),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.calculate_outlined),
            title: const Text('Checkoutrechner'),
            subtitle: const Text('Feste Checkoutwege nach Out-Regel'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CheckoutPage()),
            ),
          ),
        ),
      ],
    ),
  );
}
