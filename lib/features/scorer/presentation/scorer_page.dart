import '../../../shared/widgets/sport_menu.dart';
import '../../../shared/widgets/sport_page_heading.dart';
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
import '../../statistics/presentation/heatmap/scorer_heatmap_page.dart';

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
        const SportPageHeading(
          title: 'Game on.',
          subtitle:
              'Starte dein nächstes Match, trainiere gegen Bots oder setze dein Spiel fort.',
          icon: Icons.sports_score,
        ),
        const SizedBox(height: 20),
        SportMenuGroup(
          title: 'Spielen',
          actions: [
            for (final mode in ScorerOpponents.values)
              SportMenuAction(
                label: switch (mode) {
                  ScorerOpponents.players => 'Gegen Spieler spielen',
                  ScorerOpponents.bots => 'Gegen Bot spielen',
                  ScorerOpponents.mixed => 'Gemischtes Spiel',
                },
                icon: switch (mode) {
                  ScorerOpponents.players => Icons.people_outline,
                  ScorerOpponents.bots => Icons.smart_toy_outlined,
                  ScorerOpponents.mixed => Icons.groups_outlined,
                },
                onTap: () => _open(
                  context,
                  ScorerSetupPage(
                    opponents: mode,
                    account: account,
                    botStorage: botStorage,
                  ),
                ),
              ),
            SportMenuAction(
              label: 'Spiel beitreten · QR-Code / Code',
              icon: Icons.qr_code_scanner,
              onTap: () => _open(context, const ScorerJoinPage()),
            ),
            SportMenuAction(
              label: 'Gespeichertes Spiel fortsetzen',
              icon: Icons.restore,
              onTap: () => _resume(context),
            ),
          ],
        ),
        SportMenuGroup(
          title: 'Training & Analyse',
          actions: [
            SportMenuAction(
              label: 'Checkoutrechner',
              icon: Icons.calculate_outlined,
              onTap: () => _open(context, CheckoutPage(accountId: account?.id)),
            ),
            SportMenuAction(
              label: 'Autoscoring-Heatmaps',
              icon: Icons.blur_on,
              onTap: () => _open(context, const ScorerHeatmapPage()),
            ),
          ],
        ),
        SportMenuGroup(
          title: 'Kamera & Erkennung',
          collapsible: true,
          icon: Icons.videocam_outlined,
          actions: [
            SportMenuAction(
              label: 'Autoscorer · drei Kameras',
              icon: Icons.videocam_outlined,
              onTap: () => _open(context, const AutoscoringPage()),
            ),
          ],
        ),
      ],
    ),
  );

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}
