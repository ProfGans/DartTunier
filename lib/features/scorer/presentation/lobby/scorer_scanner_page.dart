import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../shared/widgets/adaptive_content.dart';
import '../../application/windows_qr_controller.dart';
import '../../domain/scorer_lobby.dart';

class ScorerScannerPage extends StatefulWidget {
  const ScorerScannerPage({super.key, this.windowsController});
  final WindowsQrController? windowsController;
  @override
  State<ScorerScannerPage> createState() => _ScorerScannerPageState();
}

class _ScorerScannerPageState extends State<ScorerScannerPage> {
  bool detected = false;
  String? error;
  int attempt = 0;
  void _detected(String value) {
    if (detected) return;
    final code = ScorerJoinCode.parse(value);
    if (code != null) {
      detected = true;
      Navigator.pop(context, code);
    } else if (error == null) {
      setState(
        () => error =
            'Dieser QR-Code ist keine Scorer-Einladung. Bitte den Code des Gastgebers scannen.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('QR-Code scannen')),
    body: !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
        ? _WindowsScanner(
            controller: widget.windowsController,
            onDetected: _detected,
            scanError: error,
          )
        : AdaptiveContentList(
            maxWidth: 720,
            children: [
              const Text(
                'Halte den QR-Code des Gastgebers in die Kamera. Der Code wird automatisch erkannt.',
              ),
              if (error != null) Text(error!),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 3 / 4,
                child: MobileScanner(
                  key: ValueKey(attempt),
                  errorBuilder: (context, error) => SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Text(
                            'Kamera nicht verfügbar. Bitte Kamerazugriff in den Geräteeinstellungen erlauben.',
                          ),
                          TextButton(
                            onPressed: () => setState(() => attempt++),
                            child: const Text('Erneut versuchen'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  onDetect: (capture) {
                    for (final barcode in capture.barcodes) {
                      if (barcode.rawValue != null) {
                        _detected(barcode.rawValue!);
                      }
                    }
                  },
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Stattdessen Code eingeben'),
              ),
            ],
          ),
  );
}

class _WindowsScanner extends StatefulWidget {
  const _WindowsScanner({
    this.controller,
    required this.onDetected,
    this.scanError,
  });
  final WindowsQrController? controller;
  final ValueChanged<String> onDetected;
  final String? scanError;
  @override
  State<_WindowsScanner> createState() => _WindowsScannerState();
}

class _WindowsScannerState extends State<_WindowsScanner>
    with WidgetsBindingObserver {
  late final controller = widget.controller ?? WindowsQrController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.addListener(_changed);
    controller.start();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    final result = controller.result;
    if (result != null) widget.onDetected(result);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      controller.start();
    } else {
      controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_changed);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdaptiveContentList(
    maxWidth: 900,
    children: [
      const Text(
        'Halte den QR-Code des Gastgebers vor deine Webcam. Der Code wird automatisch erkannt.',
      ),
      const SizedBox(height: 12),
      if (controller.cameras.length > 1)
        DropdownButtonFormField<int>(
          key: ValueKey(controller.selected),
          initialValue: controller.selected,
          isExpanded: true,
          isDense: false,
          itemHeight: null,
          decoration: const InputDecoration(labelText: 'Kamera'),
          items: [
            for (var i = 0; i < controller.cameras.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text(controller.cameras[i].name),
              ),
          ],
          onChanged: controller.busy
              ? null
              : (index) {
                  if (index != null) controller.start(index: index);
                },
        ),
      if (controller.busy)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (controller.ready)
        AspectRatio(
          aspectRatio: controller.aspectRatio,
          child: ClipRect(
            child: controller.platform.buildPreview(controller.cameraId!),
          ),
        ),
      if (widget.scanError != null) Text(widget.scanError!),
      if (controller.error != null) ...[
        Text(
          controller.error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        FilledButton(
          onPressed: controller.busy ? null : controller.start,
          child: const Text('Kamera erneut öffnen'),
        ),
      ],
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Stattdessen Code eingeben'),
      ),
    ],
  );
}
