import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'scorer_scanner_page.dart';
import '../../../../shared/widgets/adaptive_content.dart';
import '../../../accounts/presentation/widgets/account_menu_card.dart';
import '../../data/scorer_lobby_repository.dart';
import '../../domain/scorer_lobby.dart';

class ScorerJoinPage extends StatefulWidget {
  const ScorerJoinPage({super.key, this.code, this.repository});
  final String? code;
  final ScorerLobbyRepository? repository;
  @override
  State<ScorerJoinPage> createState() => _ScorerJoinPageState();
}

class _ScorerJoinPageState extends State<ScorerJoinPage> {
  late final input = TextEditingController(text: widget.code);
  late final repository = widget.repository ?? ScorerLobbyRepository();
  bool busy = false, joined = false;
  String? error;
  Future<void> _join() async {
    final code = ScorerJoinCode.parse(input.text);
    if (code == null) {
      setState(
        () => error =
            'Bitte einen gültigen Scorer-Code oder Einladungslink eingeben.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repository.join(code);
      if (mounted) setState(() => joined = true);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Beitritt nicht möglich. Bitte Online-Anmeldung, Verbindung und Gültigkeit der Einladung prüfen.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScorerScannerPage()),
    );
    if (mounted && code != null) {
      setState(() {
        input.text = code;
        error = null;
      });
    }
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scorer-Spiel beitreten')),
    body: AdaptiveContentList(
      children: [
        if (joined) ...[
          const Icon(Icons.check_circle_outline, size: 48),
          Text(
            'Du bist dabei!',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Text(
            'Dein Konto erscheint beim Gastgeber in der Teilnehmerliste. Gespielt und gezählt wird dort am gemeinsamen Board.',
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fertig'),
          ),
        ] else ...[
          const Text(
            'Melde dich mit deinem Konto an. Scanne anschließend den QR-Code des Gastgebers oder füge den Beitrittscode ein.',
          ),
          if (widget.repository == null) const AccountMenuCard(),
          if (kIsWeb ||
              defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.windows)
            OutlinedButton.icon(
              onPressed: busy ? null : _scan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Kamera öffnen · QR scannen'),
            )
          else
            const Text(
              'Auf diesem Gerät bitte den Beitrittscode oder Link einfügen.',
            ),
          TextField(
            controller: input,
            enabled: !busy,
            decoration: const InputDecoration(labelText: 'Code / Link'),
            onSubmitted: (_) {
              if (!busy) _join();
            },
          ),
          const SizedBox(height: 16),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton(
            onPressed: busy ? null : _join,
            child: Text(
              busy ? 'Beitritt läuft …' : 'Mit meinem Konto beitreten',
            ),
          ),
        ],
      ],
    ),
  );
}
