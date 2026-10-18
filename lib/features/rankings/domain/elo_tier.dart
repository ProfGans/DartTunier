import 'package:flutter/material.dart';

/// Auf- und Abstiegssystem: Tiers basierend auf dem aktuellen Elo-Wert.
///
/// Schwellenwerte:
/// - Diamant: ab 1200 Elo
/// - Platin: ab 1100 Elo
/// - Gold: ab 1000 Elo
/// - Silber: ab 900 Elo
/// - Bronze: unter 900 Elo
enum EloTier {
  diamant(
    name: 'Diamant',
    minElo: 1200,
    color: Color(0xFF00BCD4),
    icon: Icons.diamond_outlined,
  ),
  platin(
    name: 'Platin',
    minElo: 1100,
    color: Color(0xFF90A4AE),
    icon: Icons.military_tech_outlined,
  ),
  gold(
    name: 'Gold',
    minElo: 1000,
    color: Color(0xFFFFD700),
    icon: Icons.emoji_events_outlined,
  ),
  silber(
    name: 'Silber',
    minElo: 900,
    color: Color(0xFFB0BEC5),
    icon: Icons.shield_outlined,
  ),
  bronze(
    name: 'Bronze',
    minElo: 0,
    color: Color(0xFFCD7F32),
    icon: Icons.shield,
  );

  const EloTier({
    required this.name,
    required this.minElo,
    required this.color,
    required this.icon,
  });

  final String name;
  final int minElo;
  final Color color;
  final IconData icon;

  static EloTier fromElo(int elo) {
    if (elo >= 1200) return EloTier.diamant;
    if (elo >= 1100) return EloTier.platin;
    if (elo >= 1000) return EloTier.gold;
    if (elo >= 900) return EloTier.silber;
    return EloTier.bronze;
  }
}
