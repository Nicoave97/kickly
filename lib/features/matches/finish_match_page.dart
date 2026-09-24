import 'package:flutter/material.dart';
import '../../core/widgets/kickly_app_bar.dart';
import '../../core/widgets/responsive_page.dart';
import '../../models/match_model.dart';
import '../../models/match_participant.dart';
import '../../repositories/match_repository.dart';

class FinishMatchPage extends StatefulWidget {
  final String matchId;
  const FinishMatchPage({super.key, required this.matchId});
  @override
  State<FinishMatchPage> createState() => _FinishMatchPageState();
}

class _FinishMatchPageState extends State<FinishMatchPage> {
  final scoreA = TextEditingController();
  final scoreB = TextEditingController();
  late final Future<_Data> future = load();
  final Map<String, TextEditingController> goals = {};
  bool loading = false;

  Future<_Data> load() async {
    final match = await MatchRepository().getMatch(widget.matchId);
    final participants = await MatchRepository().watchParticipants(widget.matchId).first;
    final confirmed = participants.where((p) => p.confirmed).toList();
    for (final p in confirmed) {
      goals[p.userId] = TextEditingController(text: '0');
    }
    return _Data(match, confirmed);
  }

  Future<void> submit(_Data data) async {
    final a = int.tryParse(scoreA.text);
    final b = int.tryParse(scoreB.text);
    if (a == null || b == null || a < 0 || b < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inserisci un risultato valido.')));
      return;
    }
    setState(() => loading = true);
    try {
      await MatchRepository().finishMatch(
        matchId: widget.matchId,
        scoreA: a,
        scoreB: b,
        goals: {for (final e in goals.entries) e.key: int.tryParse(e.value.text) ?? 0},
        openRatings: data.match.ratingMode != RatingMode.off,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: KicklyAppBar(title: 'Chiudi partita', fallbackLocation: '/match/${widget.matchId}'),
        body: FutureBuilder<_Data>(
          future: future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final data = snapshot.data!;
            return ResponsivePage(
              maxWidth: 760,
              scrollable: true,
              child: PageReveal(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Risultato finale', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: scoreA, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: data.match.teamAName))),
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('—', style: TextStyle(fontSize: 24))),
                        Expanded(child: TextField(controller: scoreB, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: data.match.teamBName))),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const Text('Gol per giocatore', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    ...data.players.map(
                      (p) => Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(child: Text(p.profile.fullName, style: const TextStyle(fontWeight: FontWeight.w600))),
                              SizedBox(width: 90, child: TextField(controller: goals[p.userId], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Gol'))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: loading ? null : () => submit(data),
                        icon: const Icon(Icons.flag_outlined),
                        label: Text(loading ? 'Salvataggio...' : 'Termina partita'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

  @override
  void dispose() {
    scoreA.dispose();
    scoreB.dispose();
    for (final controller in goals.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

class _Data {
  final MatchModel match;
  final List<MatchParticipant> players;
  _Data(this.match, this.players);
}
