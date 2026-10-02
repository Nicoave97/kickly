import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kickly_app_bar.dart';
import '../../core/widgets/responsive_page.dart';
import '../../models/match_model.dart';
import '../../models/match_participant.dart';
import '../../repositories/match_repository.dart';
import 'widgets/team_pitch.dart';

class MatchLobbyPage extends StatefulWidget {
  final String matchId;
  const MatchLobbyPage({super.key, required this.matchId});
  @override
  State<MatchLobbyPage> createState() => _MatchLobbyPageState();
}

class _MatchLobbyPageState extends State<MatchLobbyPage> {
  late Future<MatchModel> matchFuture = MatchRepository().getMatch(widget.matchId);
  late final Stream<List<MatchParticipant>> participantsStream =
      MatchRepository().watchParticipants(widget.matchId);

  void reloadMatch() {
    if (!mounted) return;
    setState(() {
      matchFuture = MatchRepository().getMatch(widget.matchId);
    });
  }

  Future<void> action(Future<void> Function() fn, {String? success}) async {
    try {
      await fn();
      if (success != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  String inviteUrl(MatchModel match) =>
    Uri.base.resolve('#/join/${match.inviteCode}').toString();

  Future<void> shareOnWhatsApp(MatchModel match) async {
    if (match.isCompleted) return;
    final text = '${match.title}\n${DateFormat('dd/MM · HH:mm').format(match.startsAt)} · ${match.venueName}\n\nEntra nella lobby Kickly: ${inviteUrl(match)}';
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    final opened = await launchUrl(uri);
    if (!opened) await copyInvite(match);
  }

  Future<void> copyInvite(MatchModel match) async {
    if (match.isCompleted) return;
    await Clipboard.setData(ClipboardData(text: inviteUrl(match)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link invito copiato.')),
      );
    }
  }

  Future<void> closeRatings(MatchModel match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chiudere le votazioni?'),
        content: const Text('Dopo la chiusura i giocatori non potranno più modificare le proprie pagelle.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Chiudi votazioni')),
        ],
      ),
    );
    if (confirmed != true) return;
    await action(
      () async {
        await MatchRepository().closeRatings(match.id);
        reloadMatch();
      },
      success: 'Votazioni chiuse.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    return Scaffold(
      appBar: const KicklyAppBar(
        title: 'Lobby',
        fallbackLocation: '/matches',
      ),
      body: FutureBuilder<MatchModel>(
        future: matchFuture,
        builder: (context, matchSnap) {
          if (!matchSnap.hasData) return const Center(child: CircularProgressIndicator());
          final match = matchSnap.data!;
          final admin = match.isAdmin(uid);
          return StreamBuilder<List<MatchParticipant>>(
            stream: participantsStream,
            builder: (context, partSnap) {
              final participants = partSnap.data ?? const <MatchParticipant>[];
              final me = participants.where((p) => p.userId == uid).firstOrNull;
              final a = participants.where((p) => p.confirmed && p.team == 'a').toList();
              final b = participants.where((p) => p.confirmed && p.team == 'b').toList();
              final unassigned = participants.where((p) => p.confirmed && p.team == 'unassigned').toList();
              final wait = participants.where((p) => p.waiting).toList();
              final confirmed = participants.where((p) => p.confirmed).length;

              return ResponsivePage(
                maxWidth: 1120,
                scrollable: true,
                child: PageReveal(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MatchHeader(match: match, confirmed: confirmed, waitCount: wait.length),
                      const SizedBox(height: 14),
                      if (!match.isCompleted) ...[
                        _JoinArea(
                          match: match,
                          me: me,
                          onLeave: me == null
                              ? null
                              : () => action(() => MatchRepository().leaveMatch(match.id)),
                          onAttendance: me == null || me.waiting
                              ? null
                              : (status) => action(
                                  () => MatchRepository().setAttendanceStatus(match.id, status),
                                  success: status == 'confirmed'
                                      ? 'Presenza confermata.'
                                      : status == 'maybe'
                                          ? 'Presenza segnata come incerta.'
                                          : 'Hai indicato che non ci sarai.',
                                ),
                        ),
                        const SizedBox(height: 14),
                        _InviteActionsCard(
                          match: match,
                          onWhatsApp: () => shareOnWhatsApp(match),
                          onCopy: () => copyInvite(match),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: TeamPitch(
                            match: match,
                            teamA: a,
                            teamB: b,
                            unassigned: unassigned,
                            editable: admin && !match.isCompleted,
                            onDrop: (player, team, x, y) => action(
                              () => MatchRepository().setTeamPosition(match.id, player.userId, team, x: x, y: y),
                            ),
                          ),
                        ),
                      ),
                      if (wait.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _WaitlistCard(
                          players: wait,
                          admin: admin,
                          completed: match.isCompleted,
                          onPromote: (player) => action(
                            () => MatchRepository().promoteFromWaitlist(match.id, player.userId),
                            success: '${player.profile.fullName} è entrato tra i confermati.',
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (admin && !match.isCompleted)
                            FilledButton.icon(
                              onPressed: () async {
                                await context.push('/match/${match.id}/finish');
                                reloadMatch();
                              },
                              icon: const Icon(Icons.flag_outlined),
                              label: const Text('Chiudi partita e inserisci risultato'),
                            ),
                          if (match.isCompleted)
                            FilledButton.icon(
                              onPressed: () => context.push('/match/${match.id}/recap'),
                              icon: const Icon(Icons.assessment_outlined),
                              label: const Text('Vedi recap partita'),
                            ),
                          if (match.isCompleted && match.ratingsOpen && me?.confirmed == true)
                            FilledButton.icon(
                              onPressed: () => context.push('/match/${match.id}/rate'),
                              icon: const Icon(Icons.star_outline_rounded),
                              label: const Text('Compila le pagelle'),
                            ),
                          if (admin && match.isCompleted && match.ratingsOpen)
                            OutlinedButton.icon(
                              onPressed: () => closeRatings(match),
                              icon: const Icon(Icons.lock_outline_rounded),
                              label: const Text('Chiudi votazioni'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _MatchHeader extends StatelessWidget {
  final MatchModel match;
  final int confirmed;
  final int waitCount;
  const _MatchHeader({required this.match, required this.confirmed, required this.waitCount});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(match.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      _Meta(icon: Icons.calendar_today_outlined, text: DateFormat('EEEE d MMMM · HH:mm', 'it_IT').format(match.startsAt)),
                      const SizedBox(height: 7),
                      _Meta(icon: Icons.location_on_outlined, text: match.venueName),
                    ],
                  ),
                ),
                _StatusBadge(completed: match.isCompleted),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Text('$confirmed / ${match.maxPlayers} confermati', style: const TextStyle(fontWeight: FontWeight.w700))),
                Text('$waitCount in panchina', style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (confirmed / match.maxPlayers).clamp(0, 1),
              minHeight: 7,
              borderRadius: BorderRadius.circular(20),
            ),
            if (match.isCompleted) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  '${match.teamAName}  ${match.scoreA ?? 0}  —  ${match.scoreB ?? 0}  ${match.teamBName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 17, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.textSecondary))),
        ],
      );
}

class _StatusBadge extends StatelessWidget {
  final bool completed;
  const _StatusBadge({required this.completed});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: completed ? AppColors.surfaceAlt : AppColors.primary.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          completed ? 'Conclusa' : 'Aperta',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: completed ? AppColors.textSecondary : AppColors.primary),
        ),
      );
}

class _JoinArea extends StatelessWidget {
  final MatchModel match;
  final MatchParticipant? me;
  final Future<void> Function()? onLeave;
  final Future<void> Function(String status)? onAttendance;

  const _JoinArea({
    required this.match,
    required this.me,
    this.onLeave,
    this.onAttendance,
  });

  @override
  Widget build(BuildContext context) {
    if (me == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  me!.waiting ? Icons.event_seat_outlined : Icons.check_circle_outline_rounded,
                  color: me!.waiting ? AppColors.warning : AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        me!.waiting ? 'Sei in lista d’attesa' : 'Sei nella partita',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        me!.team == 'unassigned'
                            ? 'Squadra non ancora assegnata'
                            : 'Squadra ${me!.team.toUpperCase()}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                TextButton(onPressed: onLeave, child: const Text('Esci')),
              ],
            ),
            if (!me!.waiting) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              const Text('Conferma presenza', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                'Fai sapere al gruppo se ci sarai davvero.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _AttendanceChoice(
                    label: 'Ci sono',
                    icon: Icons.check_rounded,
                    selected: me!.attendanceStatus == 'confirmed',
                    onTap: onAttendance == null ? null : () => onAttendance!('confirmed'),
                  ),
                  _AttendanceChoice(
                    label: 'Forse',
                    icon: Icons.help_outline_rounded,
                    selected: me!.attendanceStatus == 'maybe',
                    onTap: onAttendance == null ? null : () => onAttendance!('maybe'),
                  ),
                  _AttendanceChoice(
                    label: 'Non ci sono',
                    icon: Icons.close_rounded,
                    selected: me!.attendanceStatus == 'declined',
                    onTap: onAttendance == null ? null : () => onAttendance!('declined'),
                  ),
                ],
              ),
            ],
            if (me!.confirmed && me!.team == 'unassigned' && match.teamMode == TeamMode.selfChoice) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              const Text('Scegli la tua squadra', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: () => MatchRepository().setTeam(match.id, me!.userId, 'a'),
                    child: Text(match.teamAName),
                  ),
                  FilledButton(
                    onPressed: () => MatchRepository().setTeam(match.id, me!.userId, 'b'),
                    child: Text(match.teamBName),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AttendanceChoice extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _AttendanceChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return FilledButton.tonalIcon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _InviteActionsCard extends StatelessWidget {
  final MatchModel match;
  final VoidCallback onWhatsApp;
  final VoidCallback onCopy;
  const _InviteActionsCard({
    required this.match,
    required this.onWhatsApp,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.person_add_alt_1_rounded),
                  SizedBox(width: 9),
                  Text(
                    'Invita giocatori',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Chi riceve il link vedrà i dettagli della partita e potrà entrare solo dopo aver confermato l’invito.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: onWhatsApp,
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('Invia su WhatsApp'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onCopy,
                    icon: const Icon(Icons.link_rounded),
                    label: const Text('Copia link'),
                  ),
                  Chip(
                    avatar: const Icon(Icons.key_rounded, size: 16),
                    label: Text(match.inviteCode),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _WaitlistCard extends StatelessWidget {
  final List<MatchParticipant> players;
  final bool admin;
  final bool completed;
  final Future<void> Function(MatchParticipant) onPromote;
  const _WaitlistCard({required this.players, required this.admin, required this.completed, required this.onPromote});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Panchina / lista d’attesa', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              ...players.map(
                (p) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => context.push('/player/${p.userId}'),
                  leading: CircleAvatar(
                    backgroundImage: p.profile.avatarUrl == null ? null : NetworkImage(p.profile.avatarUrl!),
                    child: p.profile.avatarUrl == null ? Text(p.profile.fullName.characters.first.toUpperCase()) : null,
                  ),
                  title: Text(p.profile.fullName),
                  trailing: admin && !completed
                      ? IconButton(tooltip: 'Promuovi', onPressed: () => onPromote(p), icon: const Icon(Icons.arrow_upward_rounded))
                      : null,
                ),
              ),
            ],
          ),
        ),
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
