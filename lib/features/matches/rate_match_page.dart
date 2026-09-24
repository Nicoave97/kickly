import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kickly_app_bar.dart';
import '../../core/widgets/responsive_page.dart';
import '../../models/match_model.dart';
import '../../models/match_participant.dart';
import '../../repositories/match_repository.dart';

class RateMatchPage extends StatefulWidget {
  final String matchId;
  const RateMatchPage({super.key, required this.matchId});
  @override
  State<RateMatchPage> createState() => _RateMatchPageState();
}

class _RateMatchPageState extends State<RateMatchPage> {
  late final Future<_Data> future = load();
  final Map<String, double> votes = {};
  bool saving = false;

  Future<_Data> load() async {
    final repo = MatchRepository();
    final match = await repo.getMatch(widget.matchId);
    final players = await repo.watchParticipants(widget.matchId).first;
    final existing = await repo.getMyRatings(widget.matchId);
    votes.addAll(existing);
    return _Data(match, players);
  }

  List<MatchParticipant> eligible(_Data d) {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    final me = d.players.where((p) => p.userId == uid).firstOrNull;
    if (me == null) return [];
    return d.players.where((p) {
      if (!p.confirmed || p.userId == uid) return false;
      return switch (d.match.ratingMode) {
        RatingMode.everyone => true,
        RatingMode.teammates => me.team != 'unassigned' && p.team == me.team,
        RatingMode.opponents => me.team != 'unassigned' && p.team != 'unassigned' && p.team != me.team,
        RatingMode.off => false,
      };
    }).toList();
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await MatchRepository().submitRatings(widget.matchId, votes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pagelle salvate.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: KicklyAppBar(title: 'Pagelle', fallbackLocation: '/match/${widget.matchId}'),
        body: FutureBuilder<_Data>(
          future: future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final list = eligible(snapshot.data!);
            if (list.isEmpty) return const Center(child: Text('Nessun giocatore da votare.'));
            return ResponsivePage(
              maxWidth: 760,
              scrollable: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Valuta la partita', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('I singoli voti restano privati. Se una partita non riceve voti, non pesa sulla media.', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 18),
                  ...list.map((p) {
                    final value = votes[p.userId] ?? 7.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundImage: p.profile.avatarUrl == null ? null : NetworkImage(p.profile.avatarUrl!),
                                    child: p.profile.avatarUrl == null ? Text(p.profile.fullName.characters.first) : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(p.profile.fullName, style: const TextStyle(fontWeight: FontWeight.w700))),
                                  Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                                ],
                              ),
                              Slider(value: value, min: 5, max: 10, divisions: 10, label: value.toStringAsFixed(1), onChanged: (v) => setState(() => votes[p.userId] = v)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Salvataggio...' : 'Salva pagelle')),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      );
}

class _Data {
  final MatchModel match;
  final List<MatchParticipant> players;
  _Data(this.match, this.players);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
