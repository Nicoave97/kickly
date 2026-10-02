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
    final matchRepo = MatchRepository();
    final results = await Future.wait([
      ProfileRepository().getMine(),
      matchRepo.getUpcomingForMe(),
      StatsRepository().getStats(uid),
      StatsRepository().getHistory(uid),
    ]);

    final upcoming = results[1] as List<MatchModel>;
    _MatchDayData? matchDay;
    if (upcoming.isNotEmpty) {
      final next = upcoming.first;
      final extra = await Future.wait([
        matchRepo.currentParticipation(next.id),
        matchRepo.getAttendanceSummary(next.id),
      ]);
      final participation = extra[0] as Map<String, dynamic>?;
      final summary = extra[1] as ({int confirmed, int maybe, int pending});
      matchDay = _MatchDayData(
        match: next,
        attendanceStatus: (participation?['attendance_status'] as String?) ?? 'pending',
        attendanceConfirmed: summary.confirmed,
        attendanceMaybe: summary.maybe,
        attendancePending: summary.pending,
      );
    }

    return _HomeData(
      name: (results[0] as dynamic).fullName as String,
      upcoming: upcoming,
      stats: results[2] as PlayerStats,
      history: results[3] as List<MatchHistoryItem>,
      matchDay: matchDay,
    );
  }

  void refresh() {
    setState(() {
      future = load();
    });
  }

  Future<void> setAttendance(String matchId, String status) async {
    await MatchRepository().setAttendanceStatus(matchId, status);
    refresh();
    await future;
  }

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
                      Text(
                        data.matchDay == null
                            ? 'Il prossimo calcetto parte da qui.'
                            : _homeSubtitle(data.matchDay!.match),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
                      ),
                      const SizedBox(height: 26),
                      if (width >= 820)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: data.matchDay != null
                                  ? _MatchDayCard(
                                      data: data.matchDay!,
                                      onAttendance: (status) => setAttendance(data.matchDay!.match.id, status),
                                    )
                                  : _EmptyMatchCard(onCreate: () => context.push('/matches/new')),
                            ),
                            const SizedBox(width: 16),
                            Expanded(flex: 4, child: _FormPanel(stats: data.stats, history: data.history)),
                          ],
                        )
                      else ...[
                        if (data.matchDay != null)
                          _MatchDayCard(
                            data: data.matchDay!,
                            onAttendance: (status) => setAttendance(data.matchDay!.match.id, status),
                          )
                        else
                          _EmptyMatchCard(onCreate: () => context.push('/matches/new')),
                        const SizedBox(height: 18),
                        _FormPanel(stats: data.stats, history: data.history),
                      ],
                      if (last != null) ...[
                        const SizedBox(height: 26),
                        const _SectionTitle('ULTIMA PARTITA'),
                        const SizedBox(height: 10),
                        Card(
                          child: ListTile(
                            onTap: () => context.push('/match/${last.matchId}/recap'),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.surfaceAlt,
                              child: Icon(Icons.assessment_outlined, color: AppColors.primary),
                            ),
                            title: Text(last.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${DateFormat('dd/MM').format(last.startsAt)} · ${last.goals} gol · voto ${last.rating?.toStringAsFixed(1) ?? '—'}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${last.scoreA ?? '-'} - ${last.scoreB ?? '-'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                                const SizedBox(width: 5),
                                const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
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
                            ComingSoonCard(icon: Icons.groups_outlined, title: 'Gruppi privati', description: 'Classifiche, presenze e rivalità del tuo gruppo fisso.'),
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

  String _homeSubtitle(MatchModel match) {
    final now = DateTime.now();
    final sameDay = now.year == match.startsAt.year && now.month == match.startsAt.month && now.day == match.startsAt.day;
    if (sameDay) return 'È Match Day. Controlla presenza, squadra e ultimi dettagli.';
    return 'La prossima partita è pronta: conferma la tua presenza.';
  }
}

class _HomeData {
  final String name;
  final List<MatchModel> upcoming;
  final PlayerStats stats;
  final List<MatchHistoryItem> history;
  final _MatchDayData? matchDay;
  _HomeData({required this.name, required this.upcoming, required this.stats, required this.history, required this.matchDay});
}

class _MatchDayData {
  final MatchModel match;
  final String attendanceStatus;
  final int attendanceConfirmed;
  final int attendanceMaybe;
  final int attendancePending;
  const _MatchDayData({
    required this.match,
    required this.attendanceStatus,
    required this.attendanceConfirmed,
    required this.attendanceMaybe,
    required this.attendancePending,
  });
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

class _MatchDayCard extends StatelessWidget {
  final _MatchDayData data;
  final Future<void> Function(String status) onAttendance;
  const _MatchDayCard({required this.data, required this.onAttendance});

  String _countdown(DateTime startsAt) {
    final diff = startsAt.difference(DateTime.now());
    if (diff.isNegative) return 'PARTITA IN CORSO / DA CHIUDERE';
    if (diff.inMinutes < 60) return 'TRA ${diff.inMinutes} MIN';
    if (diff.inHours < 24) return 'TRA ${diff.inHours}H ${diff.inMinutes.remainder(60)}M';
    if (diff.inDays == 1) return 'DOMANI';
    return 'TRA ${diff.inDays} GIORNI';
  }

  @override
  Widget build(BuildContext context) {
    final match = data.match;
    final confirmedPlayers = data.attendanceConfirmed;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _countdown(match.startsAt),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: .7),
                  ),
                ),
                const Icon(Icons.sports_soccer_rounded, color: AppColors.primary),
              ],
            ),
            const SizedBox(height: 8),
            Text(match.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -.3)),
            const SizedBox(height: 14),
            _InfoLine(icon: Icons.calendar_today_outlined, text: DateFormat('EEE d MMM · HH:mm', 'it_IT').format(match.startsAt)),
            const SizedBox(height: 7),
            _InfoLine(icon: Icons.location_on_outlined, text: match.venueName),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill(icon: Icons.check_circle_outline, text: '$confirmedPlayers confermati'),
                if (data.attendanceMaybe > 0) _Pill(icon: Icons.help_outline_rounded, text: '${data.attendanceMaybe} forse'),
                if (data.attendancePending > 0) _Pill(icon: Icons.schedule_rounded, text: '${data.attendancePending} da confermare'),
              ],
            ),
            const SizedBox(height: 18),
            if (data.attendanceStatus == 'pending') ...[
              const Text('Tu ci sarai?', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(onPressed: () => onAttendance('confirmed'), icon: const Icon(Icons.check_rounded), label: const Text('Ci sono')),
                  OutlinedButton(onPressed: () => onAttendance('maybe'), child: const Text('Forse')),
                  TextButton(onPressed: () => onAttendance('declined'), child: const Text('Non ci sono')),
                ],
              ),
              const SizedBox(height: 12),
            ] else
              _AttendanceBanner(status: data.attendanceStatus),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => context.push('/match/${match.id}'),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Apri Match Day'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceBanner extends StatelessWidget {
  final String status;
  const _AttendanceBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, text) = switch (status) {
      'confirmed' => (Icons.check_circle_rounded, 'Hai confermato: ci sarai.'),
      'maybe' => (Icons.help_rounded, 'Hai indicato: forse.'),
      'declined' => (Icons.cancel_outlined, 'Hai indicato che non ci sarai.'),
      _ => (Icons.schedule_rounded, 'Presenza da confermare.'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Pill({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(icon, size: 15, color: AppColors.textSecondary), const SizedBox(width: 5), Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))],
        ),
      );
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
  final List<MatchHistoryItem> history;
  const _FormPanel({required this.stats, required this.history});

  @override
  Widget build(BuildContext context) {
    final recent = history.where((h) => h.rating != null).take(5).toList();
    return Column(
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
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ultime valutazioni', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    children: recent.map((h) => Chip(label: Text(h.rating!.toStringAsFixed(1)))).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
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
              const Text('Crea una lobby e fai partire il prossimo Match Day.', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              FilledButton(onPressed: onCreate, child: const Text('Organizza una partita')),
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
