import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/match_model.dart';
import '../models/match_participant.dart';
import '../models/match_recap.dart';

class CreateMatchInput {
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

  const CreateMatchInput({
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
  });
}

class MatchRepository {
  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  String _teamMode(TeamMode mode) => mode == TeamMode.selfChoice ? 'self' : 'admin';
  String _ratingMode(RatingMode mode) => switch (mode) {
        RatingMode.off => 'off',
        RatingMode.teammates => 'teammates',
        RatingMode.everyone => 'all',
        RatingMode.opponents => 'opponents',
      };

  Future<MatchModel> createMatch(CreateMatchInput input) async {
    final row = await _db.from('matches').insert({
      'creator_id': _uid,
      'title': input.title.trim(),
      'starts_at': input.startsAt.toUtc().toIso8601String(),
      'venue_name': input.venueName.trim(),
      'venue_address': input.venueAddress?.trim().isEmpty == true
          ? null
          : input.venueAddress?.trim(),
      'max_players': input.maxPlayers,
      'bench_slots': input.benchSlots,
      'team_mode': _teamMode(input.teamMode),
      'rating_mode': _ratingMode(input.ratingMode),
      'team_a_name': input.teamAName.trim().isEmpty ? 'Squadra A' : input.teamAName.trim(),
      'team_b_name': input.teamBName.trim().isEmpty ? 'Squadra B' : input.teamBName.trim(),
    }).select().single();

    final match = MatchModel.fromMap(row);
    try {
      // Anche l'organizzatore entra passando dalla stessa RPC sicura usata dagli invitati.
      await joinMatchByInviteCode(match.inviteCode);
    } catch (_) {
      await _db.from('matches').delete().eq('id', match.id);
      rethrow;
    }
    return match;
  }

  Future<MatchModel> getMatch(String id) async {
    final row = await _db.from('matches').select().eq('id', id).single();
    return MatchModel.fromMap(row);
  }

  Future<MatchModel> previewMatchInvite(String code) async {
    final response = await _db.functions.invoke(
      'match-invite',
      body: {
        'action': 'preview',
        'code': code.trim().toUpperCase(),
      },
    );

    final data = response.data;
    if (response.status < 200 ||
        response.status >= 300 ||
        data is! Map ||
        data['match'] is! Map) {
      throw Exception('Invito non valido o partita non disponibile.');
    }

    return MatchModel.fromMap(
      Map<String, dynamic>.from(data['match'] as Map),
    );
  }

  Future<String> joinMatchByInviteCode(String code) async {
    final response = await _db.functions.invoke(
      'match-invite',
      body: {
        'action': 'join',
        'code': code.trim().toUpperCase(),
      },
    );

    final data = response.data;
    if (response.status < 200 ||
        response.status >= 300 ||
        data is! Map ||
        data['match_id'] is! String) {
      final message = data is Map && data['error'] is String
          ? data['error'] as String
          : 'Impossibile entrare nella partita.';
      throw Exception(message);
    }

    return data['match_id'] as String;
  }

  Future<Set<String>> _relevantMatchIds() async {
    final created = await _db.from('matches').select('id').eq('creator_id', _uid);
    final joined = await _db.from('match_players').select('match_id').eq('user_id', _uid);
    return {
      ...created.map((e) => e['id'] as String),
      ...joined.map((e) => e['match_id'] as String),
    };
  }

  Future<List<MatchModel>> getUpcomingForMe() async {
    final ids = await _relevantMatchIds();
    if (ids.isEmpty) return [];
    final rows = await _db
        .from('matches')
        .select()
        .inFilter('id', ids.toList())
        .eq('status', 'open')
        .gte('starts_at', DateTime.now().toUtc().subtract(const Duration(hours: 3)).toIso8601String())
        .order('starts_at');
    return rows.map(MatchModel.fromMap).toList();
  }

  Future<List<MatchModel>> getCompletedForMe() async {
    final ids = await _relevantMatchIds();
    if (ids.isEmpty) return [];
    final rows = await _db
        .from('matches')
        .select()
        .inFilter('id', ids.toList())
        .eq('status', 'completed')
        .order('starts_at', ascending: false);
    return rows.map(MatchModel.fromMap).toList();
  }

  Stream<List<MatchParticipant>> watchParticipants(String matchId) {
    final base = _db
        .from('match_players')
        .stream(primaryKey: ['match_id', 'user_id'])
        .eq('match_id', matchId)
        .order('joined_at');

    return base.asyncMap((rows) async {
      final ids = rows.map((e) => e['user_id'] as String).toSet().toList();
      if (ids.isEmpty) return <MatchParticipant>[];
      final profiles = await _db.from('profiles').select().inFilter('id', ids);
      final byId = {for (final p in profiles) p['id'] as String: p};
      return rows
          .where((r) => byId.containsKey(r['user_id']))
          .map((r) => MatchParticipant.fromMaps(
                r,
                byId[r['user_id']]!,
              ))
          .toList();
    });
  }

  Future<Map<String, dynamic>?> currentParticipation(String matchId) {
    return _db
        .from('match_players')
        .select()
        .eq('match_id', matchId)
        .eq('user_id', _uid)
        .maybeSingle();
  }

  Future<void> leaveMatch(String matchId) async {
    await _db
        .from('match_players')
        .delete()
        .eq('match_id', matchId)
        .eq('user_id', _uid);
  }

  Future<void> setTeam(String matchId, String userId, String team) async {
    await _db
        .from('match_players')
        .update({'team': team})
        .eq('match_id', matchId)
        .eq('user_id', userId);
  }

  Future<void> setTeamPosition(
    String matchId,
    String userId,
    String team, {
    required double x,
    required double y,
  }) async {
    await _db
        .from('match_players')
        .update({
          'team': team,
          'position_x': x.clamp(0.0, 1.0),
          'position_y': y.clamp(0.0, 1.0),
        })
        .eq('match_id', matchId)
        .eq('user_id', userId);
  }

  Future<void> promoteFromWaitlist(String matchId, String userId) async {
    await _db
        .from('match_players')
        .update({'status': 'confirmed', 'team': 'unassigned'})
        .eq('match_id', matchId)
        .eq('user_id', userId);
  }

  Future<void> finishMatch({
    required String matchId,
    required int scoreA,
    required int scoreB,
    required Map<String, int> goals,
    required bool openRatings,
  }) async {
    await _db.rpc('finish_match', params: {
      'p_match_id': matchId,
      'p_score_a': scoreA,
      'p_score_b': scoreB,
      'p_open_ratings': openRatings,
      'p_goals': goals,
    });
  }

  Future<Map<String, double>> getMyRatings(String matchId) async {
    final rows = await _db
        .from('ratings')
        .select('to_user_id,rating')
        .eq('match_id', matchId)
        .eq('from_user_id', _uid);
    return {
      for (final row in rows)
        row['to_user_id'] as String: (row['rating'] as num).toDouble(),
    };
  }

  Future<void> submitRatings(String matchId, Map<String, double> ratings) async {
    if (ratings.isEmpty) return;
    final payload = ratings.entries
        .map((e) => {
              'match_id': matchId,
              'from_user_id': _uid,
              'to_user_id': e.key,
              'rating': e.value,
            })
        .toList();
    await _db.from('ratings').upsert(
          payload,
          onConflict: 'match_id,from_user_id,to_user_id',
        );
  }


  Future<void> setAttendanceStatus(String matchId, String status) async {
    const allowed = {'pending', 'confirmed', 'maybe', 'declined'};
    if (!allowed.contains(status)) {
      throw ArgumentError('Stato presenza non valido');
    }
    await _db
        .from('match_players')
        .update({'attendance_status': status})
        .eq('match_id', matchId)
        .eq('user_id', _uid);
  }

  Future<({int confirmed, int maybe, int pending})> getAttendanceSummary(String matchId) async {
    final rows = await _db
        .from('match_players')
        .select('attendance_status,status')
        .eq('match_id', matchId);
    var confirmed = 0;
    var maybe = 0;
    var pending = 0;
    for (final row in rows) {
      if (row['status'] != 'confirmed') continue;
      switch (row['attendance_status']) {
        case 'confirmed':
          confirmed++;
          break;
        case 'maybe':
          maybe++;
          break;
        case 'pending':
          pending++;
          break;
        default:
          break;
      }
    }
    return (confirmed: confirmed, maybe: maybe, pending: pending);
  }

  Future<MatchRecap> getMatchRecap(String matchId) async {
    final match = await getMatch(matchId);
    final participants = await watchParticipants(matchId).first;
    final rows = await _db
        .from('match_player_stats')
        .select('user_id,goals,rating_avg,rating_count')
        .eq('match_id', matchId);
    final byUser = {for (final row in rows) row['user_id'] as String: row};
    final players = participants
        .where((p) => p.confirmed)
        .map((p) {
          final row = byUser[p.userId];
          return MatchRecapPlayer(
            participant: p,
            goals: (row?['goals'] as num?)?.toInt() ?? 0,
            rating: (row?['rating_avg'] as num?)?.toDouble(),
            ratingCount: (row?['rating_count'] as num?)?.toInt() ?? 0,
          );
        })
        .toList();
    return MatchRecap(match: match, players: players);
  }

  Future<void> closeRatings(String matchId) async {
    await _db.rpc('close_match_ratings', params: {'p_match_id': matchId});
  }
}
