import 'package:flutter/material.dart';
import '../../application/autoscore_audio_controller.dart';

class AutoscoreAudioControls extends StatelessWidget {
  const AutoscoreAudioControls({super.key, required this.controller});
  final AutoscoreAudioController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Card(
      child: ExpansionTile(
        title: const Text('Caller und Sounds'),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Score nach drei Würfen ansagen'),
                  subtitle: const Text(
                    'Deutsch · Bouncer zählen als Wurf mit 0 Punkten.',
                  ),
                  value: controller.caller,
                  onChanged: controller.setCaller,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Treffer- und Bouncer-Sounds'),
                  value: controller.sounds,
                  onChanged: controller.setSounds,
                ),
                Text('Lautstärke: ${(controller.volume * 100).round()} %'),
                Slider(
                  value: controller.volume,
                  onChanged: controller.setVolume,
                  label: 'Lautstärke',
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: controller.testCaller,
                      child: const Text('Caller testen'),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () => controller.testEffect(false),
                      child: const Text('Treffer testen'),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () => controller.testEffect(true),
                      child: const Text('Bouncer testen'),
                    ),
                  ],
                ),
                if (controller.error != null) Text(controller.error!),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
