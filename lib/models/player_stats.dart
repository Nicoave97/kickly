class PlayerStats {
  final String userId;
  final int matchesPlayed;
  final int goals;
  final int wins;
  final int draws;
  final int losses;
  final double? averageRating;
  final double? bestRating;
  final int mvpCount;
  final String? favoriteVenue;

  const PlayerStats({
    required this.userId,
    required this.matchesPlayed,
    required this.goals,
    required this.wins,
    required this.draws,
    required this.losses,
    this.averageRating,
    this.bestRating,
    required this.mvpCount,
    this.favoriteVenue,
  });

  double get winRate => matchesPlayed == 0 ? 0 : (wins / matchesPlayed) * 100;
  double get goalsPerMatch => matchesPlayed == 0 ? 0 : goals / matchesPlayed;

  factory PlayerStats.empty(String userId) => PlayerStats(
        userId: userId,
        matchesPlayed: 0,
        goals: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        mvpCount: 0,
      );

  factory PlayerStats.fromMap(Map<String, dynamic> map) {
    return PlayerStats(
      userId: map['user_id'] as String,
      matchesPlayed: (map['matches_played'] as num?)?.toInt() ?? 0,
      goals: (map['goals'] as num?)?.toInt() ?? 0,
      wins: (map['wins'] as num?)?.toInt() ?? 0,
      draws: (map['draws'] as num?)?.toInt() ?? 0,
      losses: (map['losses'] as num?)?.toInt() ?? 0,
      averageRating: (map['average_rating'] as num?)?.toDouble(),
      bestRating: (map['best_rating'] as num?)?.toDouble(),
      mvpCount: (map['mvp_count'] as num?)?.toInt() ?? 0,
      favoriteVenue: map['favorite_venue'] as String?,
    );
  }
}

class MatchHistoryItem {
  final String matchId;
  final String title;
  final DateTime startsAt;
  final String venueName;
  final int? scoreA;
  final int? scoreB;
  final int goals;
  final double? rating;

  const MatchHistoryItem({
    required this.matchId,
    required this.title,
    required this.startsAt,
    required this.venueName,
    this.scoreA,
    this.scoreB,
    required this.goals,
    this.rating,
  });
}
