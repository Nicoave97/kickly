enum TeamMode { selfChoice, admin }
enum RatingMode { off, teammates, everyone, opponents }

class MatchModel {
  final String id;
  final String creatorId;
  final String title;
  final DateTime startsAt;
  final String venueName;
  final String? venueAddress;
  final int maxPlayers;
  final int benchSlots;
  final TeamMode teamMode;
  final RatingMode ratingMode;
  final String teamAName;
  final String teamBName;
  final String status;
  final int? scoreA;
  final int? scoreB;
  final bool ratingsOpen;
  final String inviteCode;

  const MatchModel({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.startsAt,
    required this.venueName,
    this.venueAddress,
    required this.maxPlayers,
    required this.benchSlots,
    required this.teamMode,
    required this.ratingMode,
    required this.teamAName,
    required this.teamBName,
    required this.status,
    this.scoreA,
    this.scoreB,
    required this.ratingsOpen,
    required this.inviteCode,
  });

  bool isAdmin(String userId) => creatorId == userId;
  bool get isCompleted => status == 'completed';

  factory MatchModel.fromMap(Map<String, dynamic> map) {
    return MatchModel(
      id: map['id'] as String,
      creatorId: map['creator_id'] as String,
      title: (map['title'] as String?) ?? 'Partita',
      startsAt: DateTime.parse(map['starts_at'] as String).toLocal(),
      venueName: (map['venue_name'] as String?) ?? '',
      venueAddress: map['venue_address'] as String?,
      maxPlayers: (map['max_players'] as num).toInt(),
      benchSlots: (map['bench_slots'] as num).toInt(),
      teamMode: (map['team_mode'] == 'self')
          ? TeamMode.selfChoice
          : TeamMode.admin,
      ratingMode: switch (map['rating_mode']) {
        'teammates' => RatingMode.teammates,
        'all' => RatingMode.everyone,
        'opponents' => RatingMode.opponents,
        _ => RatingMode.off,
      },
      teamAName: (map['team_a_name'] as String?) ?? 'Squadra A',
      teamBName: (map['team_b_name'] as String?) ?? 'Squadra B',
      status: (map['status'] as String?) ?? 'open',
      scoreA: (map['score_a'] as num?)?.toInt(),
      scoreB: (map['score_b'] as num?)?.toInt(),
      ratingsOpen: (map['ratings_open'] as bool?) ?? false,
      inviteCode: (map['invite_code'] as String?) ?? '',
    );
  }
}
