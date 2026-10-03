import 'package:flutter/material.dart';
import 'dart:io';
import 'linux_push_device_menu.dart';
import '../application/push_reception_controller.dart';

class PushDeviceMenu extends StatefulWidget {
  const PushDeviceMenu({super.key});
  @override
  State<PushDeviceMenu> createState() => _PushDeviceMenuState();
}

class _PushDeviceMenuState extends State<PushDeviceMenu>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin<PushDeviceMenu> {
  @override
  bool get wantKeepAlive => true;
  final controller = PushReceptionController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.onMessage = (message) {
      if (!mounted || !controller.enabled) return;
      final notification = message.notification;
      if (notification == null) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(notification.title ?? 'App-Nachricht'),
          scrollable: true,
          content: Text(notification.body ?? ''),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Schließen'),
            ),
          ],
        ),
      );
    };
    controller.initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        PushReceptionController.supported) {
      controller.refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  Future<void> configure() async {
    final input = TextEditingController(text: controller.name);
    final route = DialogRoute<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Push auf diesem Gerät'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Empfange App-Nachrichten und deine aktivierten Turniererinnerungen, auch wenn die App geschlossen ist.',
            ),
            TextField(
              controller: input,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Gerätename'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text),
            child: const Text('Aktivieren'),
          ),
        ],
      ),
    );
    final name = await Navigator.of(context).push(route);
    await route.completed;
    input.dispose();
    if (name != null && mounted) await controller.configure(true, name);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (Platform.isLinux) return const LinuxPushDeviceMenu();
    return !PushReceptionController.supported
        ? const SizedBox.shrink()
        : AnimatedBuilder(
            animation: controller,
            builder: (context, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Benachrichtigungen',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(controller.status),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: controller.busy ? null : configure,
                          child: Text(
                            controller.enabled
                                ? 'Push-Empfang einrichten'
                                : 'Push-Empfang aktivieren',
                          ),
                        ),
                        if (controller.enabled)
                          TextButton(
                            onPressed: controller.busy
                                ? null
                                : () => controller.configure(
                                    false,
                                    controller.name,
                                  ),
                            child: const Text('Deaktivieren'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
  }
}
