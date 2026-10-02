import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kickly_app_bar.dart';
import '../../core/widgets/responsive_page.dart';
import '../../models/match_recap.dart';
import '../../repositories/match_repository.dart';

class MatchRecapPage extends StatelessWidget {
  final String matchId;
  const MatchRecapPage({super.key, required this.matchId});

  String _shareText(MatchRecap recap) {
    final m = recap.match;
    final mvp = recap.mvp;
    final scorers = recap.topScorers;
    final lines = <String>[
      'Kickly · Recap partita',
      m.title,
      '${m.teamAName} ${m.scoreA ?? '-'} - ${m.scoreB ?? '-'} ${m.teamBName}',
      '${DateFormat('dd/MM/yyyy · HH:mm').format(m.startsAt)} · ${m.venueName}',
    ];
    if (mvp != null) {
      lines.add('MVP: ${mvp.participant.profile.fullName} · ${mvp.rating!.toStringAsFixed(1)}');
    }
    if (scorers.isNotEmpty) {
      lines.add('Gol: ${scorers.map((p) => '${p.participant.profile.fullName} ${p.goals}').join(' · ')}');
    }
    return lines.join('\n');
  }

  Future<void> _shareWhatsApp(BuildContext context, MatchRecap recap) async {
    final text = _shareText(recap);
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    final ok = await launchUrl(uri);
    if (!ok && context.mounted) {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recap copiato negli appunti.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: KicklyAppBar(
        title: 'Recap partita',
        fallbackLocation: '/match/$matchId',
      ),
      body: FutureBuilder<MatchRecap>(
        future: MatchRepository().getMatchRecap(matchId),
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Impossibile caricare il recap: ${snapshot.error}'));
          }
          final recap = snapshot.data!;
          final match = recap.match;
          final mvp = recap.mvp;
          final sorted = [...recap.players]
            ..sort((a, b) => (b.rating ?? -1).compareTo(a.rating ?? -1));

          return ResponsivePage(
            maxWidth: 920,
            scrollable: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Text(
                          match.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${DateFormat('EEEE d MMMM · HH:mm', 'it_IT').format(match.startsAt)} · ${match.venueName}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(child: _TeamScore(name: match.teamAName, score: match.scoreA)),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('—', style: TextStyle(fontSize: 26, color: AppColors.textSecondary)),
                            ),
                            Expanded(child: _TeamScore(name: match.teamBName, score: match.scoreB)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (mvp != null) ...[
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundImage: mvp.participant.profile.avatarUrl == null
                                ? null
                                : NetworkImage(mvp.participant.profile.avatarUrl!),
                            child: mvp.participant.profile.avatarUrl == null
                                ? Text(mvp.participant.profile.fullName.characters.first.toUpperCase())
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('MVP DELLA PARTITA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: .6)),
                                const SizedBox(height: 3),
                                Text(mvp.participant.profile.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                                Text('${mvp.goals} gol · ${mvp.ratingCount} voti', style: const TextStyle(color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          Text(mvp.rating!.toStringAsFixed(1), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Text('PAGELLE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: .7)),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < sorted.length; i++) ...[
                        _PlayerRow(player: sorted[i]),
                        if (i != sorted.length - 1) const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => _shareWhatsApp(context, recap),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Condividi recap su WhatsApp'),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TeamScore extends StatelessWidget {
  final String name;
  final int? score;
  const _TeamScore({required this.name, required this.score});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('${score ?? '-'}', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, height: 1)),
        ],
      );
}

class _PlayerRow extends StatelessWidget {
  final MatchRecapPlayer player;
  const _PlayerRow({required this.player});

  @override
  Widget build(BuildContext context) {
    final profile = player.participant.profile;
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: profile.avatarUrl == null ? null : NetworkImage(profile.avatarUrl!),
        child: profile.avatarUrl == null ? Text(profile.fullName.characters.first.toUpperCase()) : null,
      ),
      title: Text(profile.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('${player.goals} gol · ${player.ratingCount} voti'),
      trailing: Text(
        player.rating?.toStringAsFixed(1) ?? '—',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
    );
  }
}
