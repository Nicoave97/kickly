import 'match_model.dart';
import 'match_participant.dart';

class MatchRecapPlayer {
  final MatchParticipant participant;
  final int goals;
  final double? rating;
  final int ratingCount;

  const MatchRecapPlayer({
    required this.participant,
    required this.goals,
    required this.rating,
    required this.ratingCount,
  });
}

class MatchRecap {
  final MatchModel match;
  final List<MatchRecapPlayer> players;

  const MatchRecap({required this.match, required this.players});

  MatchRecapPlayer? get mvp {
    final rated = players.where((p) => p.rating != null).toList()
      ..sort((a, b) => b.rating!.compareTo(a.rating!));
    return rated.isEmpty ? null : rated.first;
  }

  List<MatchRecapPlayer> get topScorers {
    final withGoals = players.where((p) => p.goals > 0).toList()
      ..sort((a, b) => b.goals.compareTo(a.goals));
    return withGoals.take(3).toList();
  }
}
