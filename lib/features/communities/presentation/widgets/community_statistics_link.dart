import 'package:flutter/material.dart';

class CommunityStatisticsLink extends StatelessWidget {
  const CommunityStatisticsLink({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon,
  });
  final String title, subtitle;
  final VoidCallback onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Card(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
        if (constraints.maxWidth >= 500 * scale) {
          return ListTile(
            leading: icon == null ? null : Icon(icon),
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTap,
          );
        }
        return InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (icon != null) Icon(icon),
                    const Spacer(),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(subtitle),
              ],
            ),
          ),
        );
      },
    ),
  );
}
