import 'package:flutter/material.dart';

class SportDestination {
  const SportDestination(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// Navigation follows available space and text size, never the platform.
class SportAppShell extends StatelessWidget {
  const SportAppShell({
    super.key,
    required this.child,
    required this.destinations,
    this.selected = 0,
  });
  final Widget child;
  final List<SportDestination> destinations;
  final int selected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          constraints.maxWidth >= 1100 &&
          MediaQuery.textScalerOf(context).scale(16) <= 24;
      // Keep the content at the same element-tree position across resizing.
      return Row(
        children: [
          Offstage(
            offstage: !wide,
            child: SizedBox(
              width: 248,
              child: Material(
                color: const Color(0xFF142B3A),
                child: SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(12, 18, 12, 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.sports_score,
                              color: Color(0xFF70E0BA),
                              size: 36,
                            ),
                            SizedBox(height: 14),
                            Text(
                              'DART',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                              ),
                            ),
                            Text(
                              'TURNIERVERWALTUNG',
                              style: TextStyle(
                                color: Color(0xFFB8CED8),
                                fontSize: 11,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (var i = 0; i < destinations.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            selected: selected == i,
                            selectedTileColor: const Color(0xFF254958),
                            selectedColor: const Color(0xFF70E0BA),
                            textColor: const Color(0xFFE0ECF1),
                            iconColor: const Color(0xFFB8CED8),
                            leading: Icon(destinations[i].icon),
                            title: Text(destinations[i].label),
                            onTap: selected == i ? null : destinations[i].onTap,
                          ),
                        ),
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'DEIN SPIEL. DEIN TURNIER.',
                          style: TextStyle(
                            color: Color(0xFFB8CED8),
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Offstage(
                  offstage: wide,
                  child: Material(
                    color: const Color(0xFF142B3A),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.sports_score,
                              color: Color(0xFF70E0BA),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                destinations[selected].label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            PopupMenuButton<int>(
                              tooltip: 'Bereich wechseln',
                              icon: const Icon(Icons.menu, color: Colors.white),
                              onSelected: (index) =>
                                  destinations[index].onTap(),
                              itemBuilder: (_) => [
                                for (var i = 0; i < destinations.length; i++)
                                  PopupMenuItem(
                                    value: i,
                                    child: Row(
                                      children: [
                                        Icon(destinations[i].icon),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(destinations[i].label),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      );
    },
  );
}
