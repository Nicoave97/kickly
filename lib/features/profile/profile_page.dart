import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/coming_soon_card.dart';
import '../../core/widgets/responsive_page.dart';
import '../../models/player_stats.dart';
import '../../models/profile_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/stats_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<List<dynamic>> future = load();

  Future<List<dynamic>> load() {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    return Future.wait([
      ProfileRepository().getMine(),
      StatsRepository().getStats(uid),
      StatsRepository().getHistory(uid),
    ]);
  }

  void reload() {
    setState(() {
      future = load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final profile = snapshot.data![0] as ProfileModel;
        final stats = snapshot.data![1] as PlayerStats;
        final history = snapshot.data![2] as List<MatchHistoryItem>;
        final recent = history.where((h) => h.rating != null).take(5).toList();

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            ResponsivePage(
              maxWidth: 960,
              child: PageReveal(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    _ProfileHero(profile: profile, stats: stats),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cards = [
                          _CareerCard(
                            title: 'Rendimento',
                            icon: Icons.query_stats_rounded,
                            children: [
                              _CareerRow(label: 'Vittorie', value: '${stats.wins}'),
                              _CareerRow(label: 'Pareggi', value: '${stats.draws}'),
                              _CareerRow(label: 'Sconfitte', value: '${stats.losses}'),
                              _CareerRow(label: 'Win rate', value: '${stats.winRate.toStringAsFixed(0)}%'),
                            ],
                          ),
                          _CareerCard(
                            title: 'Record personali',
                            icon: Icons.workspace_premium_outlined,
                            children: [
                              _CareerRow(label: 'Miglior voto', value: stats.bestRating?.toStringAsFixed(1) ?? '—'),
                              _CareerRow(label: 'Gol / partita', value: stats.goalsPerMatch.toStringAsFixed(2)),
                              _CareerRow(label: 'MVP', value: '${stats.mvpCount}'),
                              _CareerRow(label: 'Campo preferito', value: stats.favoriteVenue ?? '—'),
                            ],
                          ),
                        ];
                        if (constraints.maxWidth < 720) {
                          return Column(children: [cards[0], const SizedBox(height: 12), cards[1]]);
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [Expanded(child: cards[0]), const SizedBox(width: 12), Expanded(child: cards[1])],
                        );
                      },
                    ),
                    if (recent.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('FORMA RECENTE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: .7)),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 9,
                                runSpacing: 9,
                                children: recent
                                    .map((h) => _RatingDot(value: h.rating!, title: h.title))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () async {
                        await context.push('/profile/edit');
                        reload();
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Modifica profilo'),
                    ),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const first = ComingSoonCard(icon: Icons.groups_outlined, title: 'Gruppi privati', description: 'Classifiche, presenze e rivalità del tuo gruppo.');
                        const second = ComingSoonCard(icon: Icons.emoji_events_outlined, title: 'Tornei', description: 'Tornei, classifiche e voto MVP del pubblico tramite QR.');
                        if (constraints.maxWidth < 680) return const Column(children: [first, second]);
                        return const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: first), SizedBox(width: 12), Expanded(child: second)]);
                      },
                    ),
                    if (AppConfig.donationUrl.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () => launchUrl(Uri.parse(AppConfig.donationUrl)),
                        icon: const Icon(Icons.local_cafe_outlined),
                        label: const Text('Offri un caffè al fondatore'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => AuthRepository().signOut(),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Esci'),
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

class _ProfileHero extends StatelessWidget {
  final ProfileModel profile;
  final PlayerStats stats;
  const _ProfileHero({required this.profile, required this.stats});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.surfaceAlt,
                backgroundImage: profile.avatarUrl == null ? null : NetworkImage(profile.avatarUrl!),
                child: profile.avatarUrl == null
                    ? Text(profile.fullName.characters.first.toUpperCase(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700))
                    : null,
              ),
              const SizedBox(height: 12),
              Text(profile.fullName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text('@${profile.username}', style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 5),
              Text(profile.preferredRole, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _Mini('Media', stats.averageRating?.toStringAsFixed(2) ?? '—'),
                  _Mini('Gol', '${stats.goals}'),
                  _Mini('Partite', '${stats.matchesPlayed}'),
                  _Mini('MVP', '${stats.mvpCount}'),
                ],
              ),
            ],
          ),
        ),
      );
}

class _CareerCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _CareerCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            children: [
              Row(
                children: [Icon(icon, color: AppColors.primary), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w800))],
              ),
              const SizedBox(height: 14),
              ...children,
            ],
          ),
        ),
      );
}

class _CareerRow extends StatelessWidget {
  final String label;
  final String value;
  const _CareerRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
            Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800))),
          ],
        ),
      );
}

class _RatingDot extends StatelessWidget {
  final double value;
  final String title;
  const _RatingDot({required this.value, required this.title});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: title,
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceAlt,
            border: Border.all(color: AppColors.border),
          ),
          child: Text(value.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      );
}

class _Mini extends StatelessWidget {
  final String label;
  final String value;
  const _Mini(this.label, this.value);
  @override
  Widget build(BuildContext context) => Container(
        width: 130,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      );
}
