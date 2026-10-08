import '../../../shared/widgets/sport_settings_section.dart';
import 'package:flutter/material.dart';
import '../../../shared/widgets/adaptive_content.dart';
import '../data/app_push_repository.dart';

class PushSenderPage extends StatefulWidget {
  const PushSenderPage({super.key, this.repository});
  final AppPushRepository? repository;
  @override
  State<PushSenderPage> createState() => _PushSenderPageState();
}

class _PushSenderPageState extends State<PushSenderPage> {
  late final repository = widget.repository ?? AppPushRepository();
  late Future<List<PushDevice>> devices = repository.devices();
  final title = TextEditingController(), body = TextEditingController();
  final selected = <String>{};
  String _query = '';
  final form = GlobalKey<FormState>();
  bool busy = false;
  String? result, requestId;
  String? attemptedPayload;

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (!form.currentState!.validate() || selected.isEmpty || busy) return;
    if (selected.length > 100) {
      setState(() => result = 'Bitte höchstens 100 Geräte auswählen.');
      return;
    }
    final ids = selected.toList()..sort();
    final payload =
        '${title.text.trim()}\u0000${body.text.trim()}\u0000${ids.join(',')}';
    if (payload != attemptedPayload) {
      requestId = repository.newRequestId();
      attemptedPayload = payload;
    }
    setState(() {
      busy = true;
      result = null;
    });
    try {
      final response = await repository.send(
        requestId: requestId!,
        title: title.text,
        body: body.text,
        deviceIds: ids,
      );
      if (!mounted) return;
      setState(() {
        result = response['status'] == 'processing'
            ? 'Versand wird verarbeitet. Erneut prüfen sendet diese Nachricht nicht doppelt.'
            : '${response['accepted'] ?? 0} an den Push-Dienst übergeben · ${response['failed'] ?? 0} fehlgeschlagen. Die Anzeige auf dem Gerät ist damit noch nicht bestätigt.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => result =
              'Versandstatus nicht abrufbar. Bitte erneut prüfen; dieselbe Anfrage wird nicht doppelt versendet.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Push-Nachricht senden')),
    body: FutureBuilder<List<PushDevice>>(
      future: devices,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return AdaptiveContentList(
            children: [
              const Text(
                'Geräte konnten nicht geladen werden. Anmeldung, Versandberechtigung und Servereinrichtung prüfen.',
              ),
              TextButton(
                onPressed: () => setState(() => devices = repository.devices()),
                child: const Text('Erneut laden'),
              ),
            ],
          );
        }
        final targets = snapshot.data!;
        return AdaptiveContentList(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Nachricht an ausgewählte App-Geräte',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Empfänger müssen Push auf ihrem Gerät aktiviert haben. Maximal 100 Geräte pro Versand.',
                ),
                if (targets.isEmpty)
                  const Text('Noch keine Geräte für Push registriert.'),
                Form(
                  key: form,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: title,
                        enabled: !busy,
                        maxLength: 80,
                        decoration: const InputDecoration(labelText: 'Titel'),
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? 'Bitte einen Titel eingeben.'
                            : null,
                      ),
                      TextFormField(
                        controller: body,
                        enabled: !busy,
                        maxLength: 1000,
                        minLines: 3,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Nachricht',
                        ),
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? 'Bitte eine Nachricht eingeben.'
                            : null,
                      ),
                    ],
                  ),
                ),
                SportSettingsSection(
                  title: 'Empfänger auswählen',
                  summary:
                      '${selected.length} von ${targets.length} Geräten ausgewählt',
                  icon: Icons.devices_outlined,
                  initiallyExpanded: true,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Geräte suchen',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                    ),
                    Text('${selected.length} Geräte ausgewählt'),
                    for (final device in targets.where(
                      (device) =>
                          '${device.name} ${device.owner} ${device.platform}'
                              .toLowerCase()
                              .contains(_query),
                    ))
                      CheckboxListTile(
                        value: selected.contains(device.id),
                        onChanged: busy
                            ? null
                            : (value) => setState(
                                () => value == true
                                    ? selected.add(device.id)
                                    : selected.remove(device.id),
                              ),
                        title: Text(device.name),
                        subtitle: Text('${device.owner} · ${device.platform}'),
                      ),
                    if (_query.isNotEmpty &&
                        !targets.any(
                          (device) =>
                              '${device.name} ${device.owner} ${device.platform}'
                                  .toLowerCase()
                                  .contains(_query),
                        ))
                      const Text('Keine passenden Geräte.'),
                  ],
                ),
                FilledButton.icon(
                  onPressed: busy || selected.isEmpty ? null : send,
                  icon: const Icon(Icons.send),
                  label: Text(
                    busy
                        ? 'Wird gesendet …'
                        : requestId == null
                        ? 'Nachricht senden'
                        : 'Senden / Status erneut prüfen',
                  ),
                ),
                if (result != null) Text(result!),
              ],
            ),
          ],
        );
      },
    ),
  );
}
