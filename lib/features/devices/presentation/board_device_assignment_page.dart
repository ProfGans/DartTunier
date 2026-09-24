import 'package:flutter/material.dart';
import '../application/board_device_dispatcher.dart';
import '../domain/app_device.dart';
import '../data/board_display_client.dart';

class BoardDeviceAssignmentPage extends StatefulWidget {
  const BoardDeviceAssignmentPage({super.key, required this.dispatcher});
  final BoardDeviceDispatcher dispatcher;
  @override
  State<BoardDeviceAssignmentPage> createState() =>
      _BoardDeviceAssignmentPageState();
}

class _BoardDeviceAssignmentPageState extends State<BoardDeviceAssignmentPage> {
  bool _busy = false;
  String? _error;
  String? _confirmation;
  Future<void> _connect(int board) async {
    final peers = widget.dispatcher.devices.discovery.peers;
    if (peers.isEmpty) {
      setState(
        () => _error =
            'Kein Gerät gefunden. Auf dem anderen Computer den Gerätemodus aktivieren.',
      );
      return;
    }
    DevicePresence selected = peers.first;
    final form = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Gerät für Board $board'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selected.device.id,
                  isExpanded: true,
                  items: [
                    for (final peer in peers)
                      DropdownMenuItem(
                        value: peer.device.id,
                        child: Text(
                          '${peer.device.name} · ${peer.address}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (id) =>
                      selected = peers.firstWhere((p) => p.device.id == id),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Anfrage senden und auf dem Zielgerät bestätigen. Die angezeigten Vergleichszahlen müssen übereinstimmen.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Anfrage senden'),
          ),
        ],
      ),
    );
    if (result != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final key = await BoardDisplayClient().requestPairing(
        address: selected.address,
        targetId: selected.device.id,
        name: widget.dispatcher.devices.settings!.self.name,
        onConfirmation: (code) {
          if (mounted) setState(() => _confirmation = code);
        },
      );
      if (!mounted) return;
      await widget.dispatcher.bind(board, selected, key);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _confirmation = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.dispatcher,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Boards auf Geräte übertragen'),
        actions: [
          IconButton(
            tooltip: 'Geräte suchen',
            onPressed: widget.dispatcher.devices.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Pro Board ein Anzeigegerät verbinden. Die Anzeige folgt automatisch der Spielplanung und den Ergebnissen. Spiele werden weiterhin in der Turnierleitung gestartet. Die Zuordnung gilt, solange diese Turnieransicht geöffnet bleibt.',
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_busy)
            Text(
              _confirmation == null
                  ? 'Kopplungsanfrage wird gesendet …'
                  : 'Vergleichszahl: $_confirmation · Bitte auf dem Zielgerät bestätigen.',
            ),
          if (_error != null) Text(_error!),
          for (
            var board = 1;
            board <= widget.dispatcher.tournament.boardCount;
            board++
          )
            Card(
              child: ListTile(
                title: Text('Board $board'),
                subtitle: Text(
                  widget.dispatcher.connections[board] == null
                      ? 'Kein Gerät zugeordnet'
                      : '${widget.dispatcher.connections[board]!.device.name}\n${widget.dispatcher.connections[board]!.status}',
                ),
                trailing: widget.dispatcher.connections[board] == null
                    ? TextButton(
                        onPressed: _busy ? null : () => _connect(board),
                        child: const Text('Verbinden'),
                      )
                    : IconButton(
                        tooltip: 'Zuordnung lösen',
                        onPressed: () => widget.dispatcher.unbind(board),
                        icon: const Icon(Icons.link_off),
                      ),
              ),
            ),
        ],
      ),
    ),
  );
}
