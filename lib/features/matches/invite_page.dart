import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/kickly_logo.dart';
import '../../core/widgets/responsive_page.dart';
import '../../models/match_model.dart';
import '../../repositories/match_repository.dart';

class InvitePage extends StatefulWidget {
  final String inviteCode;
  const InvitePage({super.key, required this.inviteCode});

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  late final Future<MatchModel> future =
      MatchRepository().previewMatchInvite(widget.inviteCode);
  bool joining = false;
  String? error;

  Future<void> join(MatchModel match) async {
    setState(() {
      joining = true;
      error = null;
    });
    try {
      final matchId =
          await MatchRepository().joinMatchByInviteCode(widget.inviteCode);
      if (mounted) context.go('/match/$matchId');
    } catch (e) {
      if (mounted) {
        setState(() {
          joining = false;
          error = 'Non è stato possibile entrare nella partita. ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ResponsivePage(
          maxWidth: 560,
          scrollable: true,
          child: FutureBuilder<MatchModel>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const _InvalidInvite();
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.only(top: 100),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final match = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 28),
                  const Center(child: KicklyLogo(fontSize: 32)),
                  const SizedBox(height: 34),
                  Text(
                    'Sei stato invitato',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Controlla i dettagli e conferma la tua partecipazione.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            match.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _InfoRow(
                            icon: Icons.calendar_today_outlined,
                            text: DateFormat(
                              'EEEE d MMMM · HH:mm',
                              'it_IT',
                            ).format(match.startsAt),
                          ),
                          const SizedBox(height: 10),
                          _InfoRow(
                            icon: Icons.location_on_outlined,
                            text: match.venueName,
                          ),
                          const SizedBox(height: 10),
                          _InfoRow(
                            icon: Icons.groups_2_outlined,
                            text: '${match.maxPlayers} posti + ${match.benchSlots} panchina',
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: joining ? null : () => join(match),
                    icon: const Icon(Icons.sports_soccer_rounded),
                    label: Text(joining ? 'Ingresso...' : 'Partecipa alla partita'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: joining ? null : () => context.go('/matches'),
                    child: const Text('Non ora'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      );
}

class _InvalidInvite extends StatelessWidget {
  const _InvalidInvite();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(
          children: [
            const Icon(Icons.link_off_rounded, size: 44),
            const SizedBox(height: 16),
            const Text(
              'Invito non valido o partita non più disponibile.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/matches'),
              child: const Text('Vai alle mie partite'),
            ),
          ],
        ),
      );
}
