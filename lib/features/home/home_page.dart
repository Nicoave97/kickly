import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/coming_soon_card.dart';
import '../../core/widgets/kickly_logo.dart';
import '../../core/widgets/responsive_page.dart';
import '../../models/match_model.dart';
import '../../models/player_stats.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/stats_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<_HomeData> future = load();

  Future<_HomeData> load() async {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    final results = await Future.wait([
      ProfileRepository().getMine(),
      MatchRepository().getUpcomingForMe(),
      StatsRepository().getStats(uid),
      StatsRepository().getHistory(uid),
    ]);
    return _HomeData(
      name: (results[0] as dynamic).fullName as String,
      upcoming: results[1] as List<MatchModel>,
      stats: results[2] as PlayerStats,
      history: results[3] as List<MatchHistoryItem>,
    );
  }

  void refresh() => setState(() => future = load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeData>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: FilledButton(onPressed: refresh, child: const Text('Riprova')));
        }
        final data = snapshot.data!;
        final next = data.upcoming.isEmpty ? null : data.upcoming.first;
        final last = data.history.isEmpty ? null : data.history.first;
        final width = MediaQuery.sizeOf(context).width;

        return RefreshIndicator(
          onRefresh: () async {
            refresh();
            await future;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              ResponsivePage(
                maxWidth: 1120,
                child: PageReveal(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (width < 900) ...[
                        const KicklyLogo(fontSize: 27),
                        const SizedBox(height: 28),
                      ],
                      Text(
                        'Ciao ${data.name.split(' ').first}',
                        style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800, letterSpacing: -.6),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Gestisci le tue partite, le squadre e le statistiche.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                      ),
                      const SizedBox(height: 26),
                      if (width >= 820)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: next != null ? _NextMatchCard(match: next) : _EmptyMatchCard(onCreate: () => context.push('/matches/new'))),
                            const SizedBox(width: 16),
                            Expanded(flex: 4, child: _FormPanel(stats: data.stats)),
                          ],
                        )
                      else ...[
                        if (next != null) _NextMatchCard(match: next) else _EmptyMatchCard(onCreate: () => context.push('/matches/new')),
                        const SizedBox(height: 18),
                        _FormPanel(stats: data.stats),
                      ],
                      if (last != null) ...[
                        const SizedBox(height: 26),
                        const _SectionTitle('ULTIMA PARTITA'),
                        const SizedBox(height: 10),
                        Card(
                          child: ListTile(
                            onTap: () => context.push('/match/${last.matchId}'),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.surfaceAlt,
                              child: Icon(Icons.flag_outlined, color: AppColors.primary),
                            ),
                            title: Text(last.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${DateFormat('dd/MM').format(last.startsAt)} · ${last.goals} gol · voto ${last.rating?.toStringAsFixed(1) ?? '—'}'),
                            trailing: Text('${last.scoreA ?? '-'} - ${last.scoreB ?? '-'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 26),
                      const _SectionTitle('IN ARRIVO'),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 720;
                          final cards = const [
                            ComingSoonCard(icon: Icons.public, title: 'Lobby pubbliche', description: 'Trova partite aperte e nuovi giocatori.'),
                            ComingSoonCard(icon: Icons.emoji_events_outlined, title: 'Tornei', description: 'Gironi, classifiche, bracket e MVP del pubblico via QR.'),
                          ];
                          if (!wide) return Column(children: cards);
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [Expanded(child: cards[0]), const SizedBox(width: 12), Expanded(child: cards[1])],
                          );
                        },
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeData {
  final String name;
  final List<MatchModel> upcoming;
  final PlayerStats stats;
  final List<MatchHistoryItem> history;
  _HomeData({required this.name, required this.upcoming, required this.stats, required this.history});
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: .7),
      );
}

class _NextMatchCard extends StatelessWidget {
  final MatchModel match;
  const _NextMatchCard({required this.match});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PROSSIMA PARTITA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: .5)),
            const SizedBox(height: 8),
            Text(match.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            _InfoLine(icon: Icons.calendar_today_outlined, text: DateFormat('EEE d MMM · HH:mm', 'it_IT').format(match.startsAt)),
            const SizedBox(height: 8),
            _InfoLine(icon: Icons.location_on_outlined, text: match.venueName),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.push('/match/${match.id}'),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Apri lobby'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLine({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 17, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.textSecondary))),
        ],
      );
}

class _FormPanel extends StatelessWidget {
  final PlayerStats stats;
  const _FormPanel({required this.stats});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('LA TUA FORMA'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatCard(value: stats.averageRating?.toStringAsFixed(2) ?? '—', label: 'Media voto', icon: Icons.star_outline_rounded),
              _StatCard(value: '${stats.goals}', label: 'Gol', icon: Icons.sports_soccer_outlined),
              _StatCard(value: '${stats.matchesPlayed}', label: 'Partite', icon: Icons.stadium_outlined),
            ],
          ),
        ],
      );
}

class _EmptyMatchCard extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyMatchCard({required this.onCreate});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.sports_soccer_outlined, size: 34, color: AppColors.primary),
              const SizedBox(height: 12),
              const Text('Nessuna partita in programma', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              const SizedBox(height: 6),
              const Text('Crea una lobby e condividila con il gruppo.', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              FilledButton(onPressed: onCreate, child: const Text('Crea partita')),
            ],
          ),
        ),
      );
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _StatCard({required this.value, required this.label, required this.icon});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 132,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
            child: Column(
              children: [
                Icon(icon, size: 21, color: AppColors.primary),
                const SizedBox(height: 8),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      );
}
