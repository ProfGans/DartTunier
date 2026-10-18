import 'package:flutter/material.dart';
import '../../../app/theme_controller.dart';
import 'package:dart_tournament_manager/shared/widgets/adaptive_content.dart';

class AppearancePanel extends StatelessWidget {
  const AppearancePanel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    return AdaptiveContentList(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Darstellung', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        ValueListenableBuilder<ThemeMode>(
          valueListenable: controller.themeModeNotifier,
          builder: (context, mode, _) {
            return DropdownButtonFormField<ThemeMode>(
              value: mode,
              decoration: const InputDecoration(labelText: 'Design‑Modus'),
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Hell')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dunkel')),
              ],
              onChanged: (value) {
                if (value != null) {
                  controller.setThemeMode(value);
                }
              },
            );
          },
        ),
      ],
    );
  }
}
