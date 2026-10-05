import 'package:flutter/material.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../data/autoscore_setup_store.dart';
import '../application/autoscore_audio_controller.dart';
import 'autoscore_demo_page.dart';
import 'widgets/autoscore_audio_controls.dart';
import 'widgets/autoscoring_preference_tile.dart';

class AutoscorerPage extends StatefulWidget {
  const AutoscorerPage({super.key, this.store});
  final AutoscoreSetupStore? store;
  @override
  State<AutoscorerPage> createState() => _AutoscorerPageState();
}

class _AutoscorerPageState extends State<AutoscorerPage> {
  late final store = widget.store ?? AutoscoreSetupStore.instance;
  late final audio = AutoscoreAudioController(setupStore: store);
  @override
  void initState() {
    super.initState();
    store.load();
  }

  Future<void> _name({bool rename = false}) async {
    var name = rename ? store.active.name : '';
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(rename ? 'Setup umbenennen' : 'Neues Autoscorer-Setup'),
        content: SingleChildScrollView(
          child: TextFormField(
            initialValue: name,
            autofocus: true,
            onChanged: (value) => name = value,
            decoration: const InputDecoration(labelText: 'Setup-Name'),
            onFieldSubmitted: (value) {
              if (value.trim().isNotEmpty) Navigator.pop(context, value);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (name.trim().isNotEmpty) Navigator.pop(context, name);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (!mounted || value == null) return;
    if (rename) {
      store.rename(value);
    } else {
      store.create(value);
    }
  }

  @override
  void dispose() {
    audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Autoscorer')),
    body: ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final setup = store.active;
        return AdaptiveContentList(
          children: [
            Text(
              'Aktuelles Setup',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            if (!store.loaded && store.error == null)
              const LinearProgressIndicator(),
            if (store.error != null) Text(store.error!),
            DropdownButtonFormField<String>(
              key: ValueKey(setup.id),
              initialValue: setup.id,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Autoscorer-Setup',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final item in store.setups)
                  DropdownMenuItem(
                    value: item.id,
                    child: Text(item.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: store.loaded
                  ? (id) {
                      if (id != null) store.select(id);
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: store.loaded ? _name : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Neues Setup'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: store.loaded ? () => _name(rename: true) : null,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Umbenennen'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statistik · ${setup.name}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      setup.accuracy == null
                          ? 'Genauigkeit: noch keine geprüften Würfe'
                          : 'Genauigkeit: ${setup.accuracy!.toStringAsFixed(1)} %',
                    ),
                    Text(
                      '${setup.correct} richtig · ${setup.incorrect} falsch · ${setup.pending} ungeprüft',
                    ),
                    Text(
                      '${setup.total} Würfe · ${setup.estimated} Schätzungen · ${setup.missing} nachgemeldet · ${setup.bouncers} Bouncer',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Beim Herausziehen zählen unkorrigierte Treffer als richtig. Jede Korrektur und jeder nachgemeldete Wurf zählt als Fehler. Die Statistik bleibt pro Setup gespeichert, auch nach einem Neustart.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const AutoscoringPreferenceTile(),
            AutoscoreAudioControls(controller: audio),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: !store.loaded
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => AutoscoreDemoPage(setupStore: store),
                      ),
                    ),
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('Kameras, Kalibrierung und Erkennung öffnen'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hier findest du die bisherigen Kameraansichten, Korrekturen und Diagnose-Exporte. Kameras werden je Setup gespeichert; nach einem Umbau oder einer Board-Drehung neu kalibrieren.',
            ),
          ],
        );
      },
    ),
  );
}
