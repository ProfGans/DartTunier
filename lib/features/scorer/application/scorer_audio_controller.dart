import '../../autoscoring/application/autoscore_audio_controller.dart';
import 'scorer_controller.dart';

/// Connects scoring events to audio without replaying history on correction,
/// resume or undo. Camera previews make effects; only confirmed visits speak.
class ScorerAudioController {
  ScorerAudioController(this.audio, ScorerController scorer) {
    _events = _effectiveEvents(scorer).length;
    _committedVisits = scorer.statisticsVisits.length;
  }
  final AutoscoreAudioController audio;
  int _events = 0, _committedVisits = 0;

  List<Map<String, dynamic>> _effectiveEvents(ScorerController scorer) {
    final events = <Map<String, dynamic>>[];
    for (final action in scorer.exportActions()) {
      if (action['type'] == 'undo') {
        if (events.isNotEmpty) events.removeLast();
      } else {
        events.add(action);
      }
    }
    return events;
  }

  void update(ScorerController scorer, {required bool provisional}) {
    final events = _effectiveEvents(scorer);
    if (events.length > _events) {
      audio.playHit(bounce: events.last['label'] == 'Bouncer');
    }
    _events = events.length;
    final visits = scorer.statisticsVisits;
    if (visits.length < _committedVisits) _committedVisits = visits.length;
    if (provisional) return;
    if (visits.length > _committedVisits) {
      final visit = visits.last;
      audio.announce(
        visit.bust
            ? 'Überworfen'
            : visit.finished
            ? '${visit.points} Punkte. ${scorer.isComplete ? 'Spiel' : 'Leg'} gewonnen.'
            : '${visit.points} Punkte',
      );
    }
    _committedVisits = visits.length;
  }
}
