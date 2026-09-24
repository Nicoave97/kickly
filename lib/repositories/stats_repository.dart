import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/player_stats.dart';

class StatsRepository {
  SupabaseClient get _db => Supabase.instance.client;

  Future<PlayerStats> getStats(String userId) async {
    final row = await _db
        .from('player_career_stats')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? PlayerStats.empty(userId) : PlayerStats.fromMap(row);
  }

  Future<List<MatchHistoryItem>> getHistory(String userId) async {
    final rows = await _db
        .from('match_player_stats')
        .select('goals,rating_avg,match:matches!match_player_stats_match_id_fkey(id,title,starts_at,venue_name,score_a,score_b,status)')
        .eq('user_id', userId);

    final result = <MatchHistoryItem>[];
    for (final row in rows) {
      final match = row['match'];
      if (match is! Map || match['status'] != 'completed') continue;
      result.add(MatchHistoryItem(
        matchId: match['id'] as String,
        title: match['title'] as String,
        startsAt: DateTime.parse(match['starts_at'] as String).toLocal(),
        venueName: match['venue_name'] as String,
        scoreA: (match['score_a'] as num?)?.toInt(),
        scoreB: (match['score_b'] as num?)?.toInt(),
        goals: (row['goals'] as num?)?.toInt() ?? 0,
        rating: (row['rating_avg'] as num?)?.toDouble(),
      ));
    }
    result.sort((a, b) => b.startsAt.compareTo(a.startsAt));
    return result;
  }
}
