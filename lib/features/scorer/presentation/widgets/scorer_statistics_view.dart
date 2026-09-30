import 'package:flutter/material.dart';
import '../../domain/scorer_settings.dart';
import '../../domain/scorer_statistics.dart';
import '../../domain/x01/x01_models.dart';

class ScorerStatisticsView extends StatelessWidget {
  const ScorerStatisticsView({
    super.key,
    required this.statistics,
    required this.settings,
  });
  final ScorerStatistics statistics;
  final ScorerSettings settings;
  String number(double? value) =>
      value == null ? '—' : value.toStringAsFixed(2).replaceAll('.', ',');
  @override
  Widget build(BuildContext context) {
    final doubleOut =
        settings.checkoutRequirement == CheckoutRequirement.doubleOut;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Matchstatistik',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Text(
            'Abgeschlossene Aufnahmen dieses Spiels · Menschen und Bots',
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: [
                const DataColumn(label: Text('Kennzahl')),
                for (final p in settings.participants)
                  DataColumn(label: Text(p.name)),
              ],
              rows: [
                _row(
                  '3-Dart-Average',
                  'Gezählte Punkte ÷ Statistik-Darts × 3.',
                  (p) => number(p.average),
                ),
                _row(
                  'First-9-Average',
                  'Erste drei Aufnahmen je Leg; ein früheres Finish zählt nur mit seinen benötigten Darts.',
                  (p) => number(p.firstNineAverage),
                ),
                if (doubleOut)
                  _row(
                    'Checkoutquote',
                    'Gewonnene Legs ÷ tatsächliche Darts auf ein beendendes Doppel/Bull × 100. Keine Quote bei unvollständigen Angaben.',
                    (p) => p.unknownCheckoutVisits > 0
                        ? 'Unvollständig (${p.unknownCheckoutVisits})'
                        : p.checkoutPercent == null
                        ? '—'
                        : '${number(p.checkoutPercent)} %',
                  ),
                if (doubleOut)
                  _row(
                    'Darts auf Checkout',
                    'Erfasste Versuche, das Leg zu beenden. Eröffnungsdoppel zählen nicht.',
                    (p) =>
                        '${p.legsWon} Treffer / ${p.checkoutAttempts} erfasst',
                  ),
                _row(
                  'Legs gewonnen / beendet',
                  'Alle beendeten Legs, auch über Setwechsel hinweg.',
                  (p) => '${p.legsWon} / ${p.legsPlayed}',
                ),
                _row(
                  'Darts je gewonnenem Leg',
                  'Statistik-Darts ausschließlich in selbst gewonnenen Legs.',
                  (p) => number(p.dartsPerWonLeg),
                ),
                _row(
                  'Bestes Leg',
                  'Wenigste Statistik-Darts für ein gewonnenes Leg.',
                  (p) => p.bestLeg == null ? '—' : '${p.bestLeg} Darts',
                ),
                _row(
                  'Höchstes Finish',
                  'Restpunktzahl vor der erfolgreichen Checkout-Aufnahme.',
                  (p) => p.legsWon == 0 ? '—' : '${p.highestFinish}',
                ),
                _row(
                  '100+-Finishes',
                  'Anzahl erfolgreicher Finishes von mindestens 100 Punkten.',
                  (p) => '${p.tonFinishes}',
                ),
                _row(
                  'Höchste Aufnahme',
                  'Höchster gewerteter Aufnahmescore; Bust zählt null.',
                  (p) => p.visits == 0 ? '—' : '${p.highestScore}',
                ),
                _row(
                  '60+ / 100+ / 140+',
                  'Inklusive Schwellen: Eine 180 zählt auch in 60+, 100+ und 140+.',
                  (p) => '${p.scores60} / ${p.scores100} / ${p.scores140}',
                ),
                _row(
                  '180er',
                  'Aufnahmen mit genau 180 gewerteten Punkten.',
                  (p) => '${p.scores180}',
                ),
                if (settings.participants.length == 2) ...[
                  _row(
                    'Breaks',
                    'Legs gegen den Anwurf gewonnen.',
                    (p) => '${p.breaks}',
                  ),
                  _row(
                    'Holds',
                    'Legs mit eigenem Anwurf gewonnen.',
                    (p) => '${p.holds}',
                  ),
                ],
                if (settings.startRequirement == StartRequirement.straightIn &&
                    doubleOut)
                  _row(
                    '9-Darter (501)',
                    '501 Punkte in genau neun Darts; nur Straight In / Double Out.',
                    (p) => '${p.nineDarters}',
                  ),
                _row(
                  'Aufnahmen / Überworfen',
                  'Anzahl abgeschlossener Aufnahmen und Busts.',
                  (p) => '${p.visits} / ${p.busts}',
                ),
                _row(
                  'Punkte / Statistik-Darts',
                  'Nicht beendende Aufnahmen inklusive Bust zählen mit drei Darts; Checkouts mit der bestätigten Anzahl.',
                  (p) => '${p.points} / ${p.darts}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Zählweise: Bust = 0 Punkte und 3 Statistik-Darts, auch bei frühem Überwerfen. '
            'First 9 beginnt mit jedem Leg neu. Fehlende Werte werden als — angezeigt. '
            'Diese Auswertung bleibt nur für die geöffnete Partie verfügbar.',
          ),
          if (!doubleOut)
            const Text(
              'Die Doppel-Checkoutquote wird nur bei Double Out angezeigt.',
            ),
          if (statistics.legs.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Leg-Verlauf', style: Theme.of(context).textTheme.titleLarge),
            for (final leg in statistics.legs)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Leg ${leg.number}: ${settings.participants[leg.winner].name}',
                ),
                subtitle: Text(
                  '${leg.darts} Darts · Finish ${leg.finish}'
                  '${settings.participants.length == 2
                      ? leg.starter == leg.winner
                            ? ' · Hold'
                            : ' · Break'
                      : ''}',
                ),
              ),
          ],
        ],
      ),
    );
  }

  DataRow _row(
    String label,
    String explanation,
    String Function(ScorerPlayerStatistics) value,
  ) => DataRow(
    cells: [
      DataCell(Tooltip(message: explanation, child: Text(label))),
      for (final p in statistics.players) DataCell(Text(value(p))),
    ],
  );
}
