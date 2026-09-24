import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive_page.dart';
import '../../models/player_stats.dart';
import '../../repositories/stats_repository.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([StatsRepository().getStats(uid), StatsRepository().getHistory(uid)]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final stats = snapshot.data![0] as PlayerStats;
        final history = snapshot.data![1] as List<MatchHistoryItem>;
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            ResponsivePage(
              maxWidth: 1120,
              child: PageReveal(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('La tua carriera', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800, letterSpacing: -.5)),
                    const SizedBox(height: 5),
                    const Text('Numeri reali, aggiornati dalle partite concluse.', style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _Box('Partite', '${stats.matchesPlayed}'),
                        _Box('Gol', '${stats.goals}'),
                        _Box('Media', stats.averageRating?.toStringAsFixed(2) ?? '—'),
                        _Box('MVP', '${stats.mvpCount}'),
                        _Box('Vittorie', '${stats.wins}'),
                        _Box('Win rate', '${stats.winRate.toStringAsFixed(0)}%'),
                        _Box('Gol/partita', stats.goalsPerMatch.toStringAsFixed(2)),
                        _Box('Miglior voto', stats.bestRating?.toStringAsFixed(1) ?? '—'),
                      ],
                    ),
                    if (stats.favoriteVenue != null) ...[
                      const SizedBox(height: 18),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.stadium_outlined, color: AppColors.primary),
                          title: const Text('Campo più giocato', style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(stats.favoriteVenue!),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    const Text('Cronologia', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    if (history.isEmpty)
                      const Text('Nessuna partita conclusa.', style: TextStyle(color: AppColors.textSecondary))
                    else
                      ...history.map(
                        (h) => Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Card(
                            child: ListTile(
                              onTap: () => context.push('/match/${h.matchId}'),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
                              title: Text(h.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('${DateFormat('dd/MM/yyyy').format(h.startsAt)} · ${h.goals} gol · voto ${h.rating?.toStringAsFixed(1) ?? '—'}'),
                              trailing: Text('${h.scoreA ?? '-'}-${h.scoreB ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Box extends StatelessWidget {
  final String label;
  final String value;
  const _Box(this.label, this.value);
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );
}
