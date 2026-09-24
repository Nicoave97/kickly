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

  void reloadMatch() => setState(() => matchFuture = MatchRepository().getMatch(widget.matchId));

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

  String inviteUrl(MatchModel match) => '${Uri.base.origin}/#/join/${match.inviteCode}';

  Future<void> share(MatchModel match) async {
    final text = '${match.title}\n${DateFormat('dd/MM · HH:mm').format(match.startsAt)} · ${match.venueName}\n\nEntra nella lobby Kickly: ${inviteUrl(match)}';
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    if (!await launchUrl(uri)) {
      await Clipboard.setData(ClipboardData(text: inviteUrl(match)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copiato.')));
      }
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
      appBar: KicklyAppBar(
        title: 'Lobby',
        fallbackLocation: '/matches',
        actions: [
          FutureBuilder<MatchModel>(
            future: matchFuture,
            builder: (context, snapshot) => IconButton(
              tooltip: 'Condividi invito',
              onPressed: snapshot.hasData ? () => share(snapshot.data!) : null,
              icon: const Icon(Icons.ios_share_rounded),
            ),
          ),
        ],
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
                      if (!match.isCompleted)
                        _JoinArea(
                          match: match,
                          me: me,
                          onJoin: (team) => action(() => MatchRepository().joinMatch(match.id, team: team)),
                          onLeave: me == null ? null : () => action(() => MatchRepository().leaveMatch(match.id)),
                        ),
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
  final Future<void> Function(String team) onJoin;
  final Future<void> Function()? onLeave;
  const _JoinArea({required this.match, required this.me, required this.onJoin, this.onLeave});

  @override
  Widget build(BuildContext context) {
    if (me != null) {
      if (me!.confirmed && me!.team == 'unassigned' && match.teamMode == TeamMode.selfChoice) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Sei dentro. Scegli la tua squadra:', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(onPressed: () => MatchRepository().setTeam(match.id, me!.userId, 'a'), child: Text(match.teamAName)),
                    FilledButton(onPressed: () => MatchRepository().setTeam(match.id, me!.userId, 'b'), child: Text(match.teamBName)),
                    TextButton(onPressed: onLeave, child: const Text('Esci dalla partita')),
                  ],
                ),
              ],
            ),
          ),
        );
      }
      return Card(
        child: ListTile(
          leading: Icon(me!.waiting ? Icons.event_seat_outlined : Icons.check_circle_outline_rounded, color: me!.waiting ? AppColors.warning : AppColors.primary),
          title: Text(me!.waiting ? 'Sei in lista d’attesa' : 'Partecipazione confermata', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(me!.team == 'unassigned' ? 'Squadra non ancora assegnata' : 'Squadra ${me!.team.toUpperCase()}'),
          trailing: TextButton(onPressed: onLeave, child: const Text('Esci')),
        ),
      );
    }
    if (match.teamMode == TeamMode.selfChoice) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton(onPressed: () => onJoin('a'), child: Text('Entra in ${match.teamAName}')),
          FilledButton(onPressed: () => onJoin('b'), child: Text('Entra in ${match.teamBName}')),
        ],
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.icon(onPressed: () => onJoin('unassigned'), icon: const Icon(Icons.check_rounded), label: const Text('Partecipo')),
    );
  }
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
