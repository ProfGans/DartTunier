import 'package:flutter/material.dart';
import 'package:dart_tournament_manager/shared/widgets/adaptive_content.dart';
import '../application/remote_host_controller.dart';

class RemoteConfirmationView extends StatelessWidget {
  const RemoteConfirmationView({super.key, required this.controller});
  final RemoteHostController controller;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface.withValues(alpha: .98),
    child: AdaptiveContentList(
      maxWidth: 640,
      children: [
        const SizedBox(height: 24),
        Text(
          'Fernsteuerung übernehmen?',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(
          '${controller.pendingName ?? 'Fernbedienung'} möchte diese App bedienen.',
        ),
        const Text(
          'Unter Geräte → App fernsteuern kannst du festlegen, ob diese Bestätigung künftig erforderlich ist.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton(
              onPressed: () => controller.answerConfirmation(false),
              child: const Text('Ablehnen'),
            ),
            FilledButton(
              onPressed: () => controller.answerConfirmation(true),
              child: const Text('Übernahme erlauben'),
            ),
          ],
        ),
      ],
    ),
  );
}
