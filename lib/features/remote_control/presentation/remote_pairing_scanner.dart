import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../scorer/presentation/lobby/scorer_scanner_page.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:dart_tournament_manager/shared/widgets/adaptive_content.dart';
import '../domain/remote_pairing_code.dart';

class RemotePairingScanner extends StatefulWidget {
  const RemotePairingScanner({super.key});
  @override
  State<RemotePairingScanner> createState() => _RemotePairingScannerState();
}

class _RemotePairingScannerState extends State<RemotePairingScanner> {
  bool _done = false;
  String? _error;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hauptgerät koppeln')),
    body:
        !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.linux ||
                defaultTargetPlatform == TargetPlatform.windows)
        ? DesktopQrScanner(
            scanError: _error,
            onDetected: (value) {
              if (_done) return;
              final code = RemotePairingCode.parse(value);
              if (code == null) {
                setState(
                  () => _error =
                      'Bitte den Fernsteuerungs-Code des Hauptgeräts scannen.',
                );
              } else {
                _done = true;
                Navigator.pop(context, code);
              }
            },
          )
        : AdaptiveContentList(
            maxWidth: 720,
            children: [
              const Text('Den QR-Code unter Geräte am Hauptgerät scannen.'),
              if (_error != null) Text(_error!),
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: 3 / 4,
                child: MobileScanner(
                  errorBuilder: (context, error) => const Center(
                    child: Text(
                      'Kamera nicht verfügbar. Kamerazugriff erlauben oder Adresse und Code manuell eingeben.',
                    ),
                  ),
                  onDetect: (capture) {
                    if (_done) return;
                    for (final barcode in capture.barcodes) {
                      final code = RemotePairingCode.parse(
                        barcode.rawValue ?? '',
                      );
                      if (code != null) {
                        _done = true;
                        Navigator.pop(context, code);
                        return;
                      }
                    }
                    if (_error == null) {
                      setState(
                        () => _error =
                            'Bitte den Fernsteuerungs-Code des Hauptgeräts scannen.',
                      );
                    }
                  },
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Manuell verbinden'),
              ),
            ],
          ),
  );
}
