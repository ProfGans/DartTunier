import '../../tournaments/application/tournament_result_importer.dart';

/// Compatibility adapter: the built-in scorer always supplies visit statistics.
class DeviceResultImporter extends TournamentResultImporter {
  const DeviceResultImporter() : super(requireStatistics: true);
}
