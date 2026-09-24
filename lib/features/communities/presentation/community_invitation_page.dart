import 'package:flutter/material.dart';
import '../../accounts/data/supabase_account_config.dart';
import '../../accounts/presentation/widgets/account_menu_card.dart';
import '../data/supabase_community_repository.dart';
import 'community_page.dart';
import '../../devices/data/community_device_repository.dart';
import '../../devices/presentation/devices_scope.dart';
import '../../devices/presentation/devices_page.dart';

class CommunityInvitationPage extends StatefulWidget {
  const CommunityInvitationPage({
    super.key,
    required this.code,
    required this.createTournamentBuilder,
    required this.runTournamentBuilder,
  });
  final String code;
  final CommunityTournamentCreationBuilder createTournamentBuilder;
  final CommunityTournamentRunBuilder runTournamentBuilder;

  @override
  State<CommunityInvitationPage> createState() =>
      _CommunityInvitationPageState();
}

class _CommunityInvitationPageState extends State<CommunityInvitationPage> {
  bool _busy = false;
  String? _error;

  Future<void> _join({bool asDevice = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!SupabaseAccountBootstrap.isInitialized) {
        throw StateError('Online-Communities sind nicht eingerichtet.');
      }
      if (asDevice) {
        final devices = DevicesScope.of(context);
        await devices.initialize();
        final device = devices.settings?.self;
        if (device == null) throw StateError('Gerät nicht verfügbar');
        await CommunityDeviceRepository().join(device, widget.code);
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const DevicesPage()),
        );
        return;
      }
      final repository = SupabaseCommunityRepository();
      final community = await repository.joinCommunity(widget.code);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CommunityDetailPage(
            community: community,
            repository: repository,
            createTournamentBuilder: widget.createTournamentBuilder,
            runTournamentBuilder: widget.runTournamentBuilder,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Beitritt nicht möglich. Bitte anmelden, Internetverbindung und Einladungscode prüfen und erneut versuchen.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Community-Einladung')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Du wurdest zu einer Community eingeladen.',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        SelectableText('Einladungscode: ${widget.code}'),
        const SizedBox(height: 12),
        const Text(
          'Melde dich bei Bedarf an und bestätige anschließend den Beitritt.',
        ),
        const AccountMenuCard(),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _join,
          child: Text(_busy ? 'Beitritt läuft …' : 'Community beitreten'),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _join(asDevice: true),
          icon: const Icon(Icons.computer),
          label: const Text('Als Gerät beitreten (Account erforderlich)'),
        ),
      ],
    ),
  );
}
