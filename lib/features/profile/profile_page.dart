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
    ]);
  }

  void reload() => setState(() => future = load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final profile = snapshot.data![0] as ProfileModel;
        final stats = snapshot.data![1] as PlayerStats;
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            ResponsivePage(
              maxWidth: 900,
              child: PageReveal(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.surfaceAlt,
                      backgroundImage: profile.avatarUrl == null ? null : NetworkImage(profile.avatarUrl!),
                      child: profile.avatarUrl == null
                          ? Text(profile.fullName.characters.first.toUpperCase(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700))
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(profile.fullName, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text('@${profile.username}', style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 3),
                    Text(profile.preferredRole, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        _Mini('Media', stats.averageRating?.toStringAsFixed(2) ?? '—'),
                        _Mini('Gol', '${stats.goals}'),
                        _Mini('Partite', '${stats.matchesPlayed}'),
                        _Mini('MVP', '${stats.mvpCount}'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () async {
                        await context.push('/profile/edit');
                        reload();
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Modifica profilo'),
                    ),
                    const SizedBox(height: 26),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const first = ComingSoonCard(icon: Icons.public, title: 'Lobby pubbliche', description: 'Partite aperte e ricerca giocatori.');
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
