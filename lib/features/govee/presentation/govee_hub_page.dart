import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../data/govee_api.dart';
import '../domain/govee_device.dart';

class GoveeHubPage extends StatefulWidget {
  const GoveeHubPage({super.key, this.api});
  final GoveeApi? api;

  @override
  State<GoveeHubPage> createState() => _GoveeHubPageState();
}

class _GoveeHubPageState extends State<GoveeHubPage> {
  final _keyController = TextEditingController();
  final _selectedDevices = <int, String>{};
  List<GoveeDevice> _devices = const [];
  String? _error;
  bool _loading = false;
  final _busyStrips = <int>{};
  late final GoveeApi _api = widget.api ?? GoveeApi(client: http.Client());

  @override
  void dispose() {
    _keyController.clear();
    _keyController.dispose();
    if (widget.api == null) _api.close();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Bitte den Govee API-Key eingeben.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final devices = await _api.devices(key);
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _selectedDevices.clear();
        for (var i = 0; i < 4 && i < devices.length; i++) {
          _selectedDevices[i] = devices[i].id;
        }
        if (devices.isEmpty) _error = 'Keine farbsteuerbaren Geräte gefunden.';
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _apply(int strip, int? rgb, {int? kelvin}) async {
    final id = _selectedDevices[strip];
    final device = _devices.where((item) => item.id == id).firstOrNull;
    if (device == null) return;
    setState(() {
      _busyStrips.add(strip);
      _error = null;
    });
    try {
      if (kelvin != null) {
        if (!device.supportsTemperature) {
          throw const GoveeApiException(
            'Dieses Gerät unterstützt keine Farbtemperatur.',
          );
        }
        await _api.setTemperature(
          apiKey: _keyController.text.trim(),
          device: device,
          kelvin: kelvin,
        );
      } else if (rgb != null) {
        if (!device.supportsRgb) {
          throw const GoveeApiException(
            'Dieses Gerät unterstützt keine RGB-Farben.',
          );
        }
        await _api.setRgb(
          apiKey: _keyController.text.trim(),
          device: device,
          rgb: rgb,
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busyStrips.remove(strip));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Govee Licht-Hub')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('API-Key bleibt nur für diese Sitzung im Speicher.'),
          const SizedBox(height: 8),
          TextField(
            controller: _keyController,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Govee API-Key',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _loading ? null : _loadDevices,
            icon: _loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: const Text('Lichtstreifen laden'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          for (var strip = 0; strip < 4; strip++) _stripCard(strip),
        ],
      ),
    ),
  );

  Widget _stripCard(int index) {
    final current = _selectedDevices[index];
    final available = _devices
        .where(
          (device) =>
              !_selectedDevices.entries.any(
                (entry) => entry.key != index && entry.value == device.id,
              ) ||
              device.id == current,
        )
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Lichtstreifen ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: available.any((device) => device.id == current)
                  ? current
                  : null,
              decoration: const InputDecoration(
                labelText: 'Govee-Gerät',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final device in available)
                  DropdownMenuItem(
                    value: device.id,
                    child: Text('${device.name} · ${device.sku}'),
                  ),
              ],
              onChanged: (value) => setState(() {
                if (value == null) {
                  _selectedDevices.remove(index);
                } else {
                  _selectedDevices[index] = value;
                }
              }),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _colorButton(index, 'Türkis', 0x40E0D0),
                _colorButton(index, 'Grün', 0x00FF00),
                _colorButton(index, 'Rot', 0xFF0000),
                _colorButton(index, 'Kaltweiß', null, kelvin: 6500),
              ],
            ),
            if (_busyStrips.contains(index)) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _colorButton(int strip, String label, int? rgb, {int? kelvin}) {
    final device = _devices
        .where((item) => item.id == _selectedDevices[strip])
        .firstOrNull;
    final supportsColor = kelvin == null
        ? device?.supportsRgb == true
        : device?.supportsTemperature == true;
    return OutlinedButton(
      onPressed: _busyStrips.contains(strip) || !supportsColor
          ? null
          : () => _apply(strip, rgb, kelvin: kelvin),
      child: Text(label),
    );
  }
}
