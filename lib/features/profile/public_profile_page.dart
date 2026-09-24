import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kickly_app_bar.dart';
import '../../core/widgets/responsive_page.dart';
import '../../models/player_stats.dart';
import '../../models/profile_model.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/stats_repository.dart';

class PublicProfilePage extends StatelessWidget {
  final String userId;
  const PublicProfilePage({super.key, required this.userId});

  Future<List<dynamic>> load() => Future.wait([
        ProfileRepository().getById(userId),
        StatsRepository().getStats(userId),
        StatsRepository().getHistory(userId),
      ]);

  Future<void> compare(BuildContext context, PlayerStats other) async {
    final mine = await StatsRepository().getStats(Supabase.instance.client.auth.currentUser!.id);
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confronto'),
        content: SingleChildScrollView(
          child: Table(
            columnWidths: const {0: FlexColumnWidth(1.5), 1: FlexColumnWidth(), 2: FlexColumnWidth()},
            children: [
              const TableRow(children: [Text(''), Text('Tu', textAlign: TextAlign.center), Text('Lui/Lei', textAlign: TextAlign.center)]),
              _row('Partite', '${mine.matchesPlayed}', '${other.matchesPlayed}'),
              _row('Gol', '${mine.goals}', '${other.goals}'),
              _row('Media', mine.averageRating?.toStringAsFixed(2) ?? '—', other.averageRating?.toStringAsFixed(2) ?? '—'),
              _row('Vittorie', '${mine.wins}', '${other.wins}'),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Chiudi'))],
      ),
    );
  }

  TableRow _row(String label, String a, String b) => TableRow(
        children: [
          Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Text(label)),
          Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Text(a, textAlign: TextAlign.center)),
          Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Text(b, textAlign: TextAlign.center)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const KicklyAppBar(title: 'Profilo giocatore', fallbackLocation: '/matches'),
      body: FutureBuilder<List<dynamic>>(
        future: load(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final profile = snapshot.data![0] as ProfileModel;
          final stats = snapshot.data![1] as PlayerStats;
          final history = snapshot.data![2] as List<MatchHistoryItem>;
          final isMe = userId == Supabase.instance.client.auth.currentUser!.id;
          return ResponsivePage(
            maxWidth: 860,
            scrollable: true,
            child: PageReveal(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.surfaceAlt,
                    backgroundImage: profile.avatarUrl == null ? null : NetworkImage(profile.avatarUrl!),
                    child: profile.avatarUrl == null ? Text(profile.fullName.characters.first.toUpperCase(), style: const TextStyle(fontSize: 30)) : null,
                  ),
                  const SizedBox(height: 11),
                  Text(profile.fullName, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
                  Text('@${profile.username}', style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(profile.preferredRole, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _Mini('Partite', '${stats.matchesPlayed}'),
                      _Mini('Gol', '${stats.goals}'),
                      _Mini('Media', stats.averageRating?.toStringAsFixed(2) ?? '—'),
                      _Mini('MVP', '${stats.mvpCount}'),
                    ],
                  ),
                  if (!isMe) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(onPressed: () => compare(context, stats), icon: const Icon(Icons.compare_arrows_rounded), label: const Text('Confronta con me')),
                  ],
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Vittorie ${stats.wins} · Win rate ${stats.winRate.toStringAsFixed(0)}%${stats.favoriteVenue == null ? '' : ' · Campo ${stats.favoriteVenue}'}', style: const TextStyle(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(height: 26),
                  const Align(alignment: Alignment.centerLeft, child: Text('Cronologia', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700))),
                  const SizedBox(height: 9),
                  if (history.isEmpty)
                    const Align(alignment: Alignment.centerLeft, child: Text('Nessuna partita conclusa.', style: TextStyle(color: AppColors.textSecondary)))
                  else
                    ...history.take(20).map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Card(
                              child: ListTile(
                                title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text('${DateFormat('dd/MM/yyyy').format(item.startsAt)} · ${item.goals} gol · voto ${item.rating?.toStringAsFixed(1) ?? '—'}'),
                                trailing: Text('${item.scoreA ?? '-'}-${item.scoreB ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ),
                        ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  final String label;
  final String value;
  const _Mini(this.label, this.value);
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 130,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              children: [
                Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
}
