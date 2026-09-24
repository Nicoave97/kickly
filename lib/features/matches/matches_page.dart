import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive_page.dart';
import '../../models/match_model.dart';
import '../../repositories/match_repository.dart';

class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});
  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  late Future<List<List<MatchModel>>> future = load();
  Future<List<List<MatchModel>>> load() async => Future.wait([
        MatchRepository().getUpcomingForMe(),
        MatchRepository().getCompletedForMe(),
      ]);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResponsivePage(
            maxWidth: 1120,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Partite', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800, letterSpacing: -.5)),
                const SizedBox(height: 5),
                const Text('Tieni separate le prossime partite dallo storico.', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 14),
                const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [Tab(text: 'Prossime'), Tab(text: 'Storico')],
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<List<MatchModel>>>(
              future: future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                return TabBarView(
                  children: [
                    _List(matches: snapshot.data![0], upcoming: true),
                    _List(matches: snapshot.data![1], upcoming: false),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _List extends StatelessWidget {
  final List<MatchModel> matches;
  final bool upcoming;
  const _List({required this.matches, required this.upcoming});

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Text(upcoming ? 'Nessuna partita in programma.' : 'Lo storico è ancora vuoto.', style: const TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          itemCount: matches.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final m = matches[index];
            return Card(
              child: ListTile(
                onTap: () => context.push('/match/${m.id}'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                leading: CircleAvatar(
                  backgroundColor: AppColors.surfaceAlt,
                  child: Icon(m.isCompleted ? Icons.flag_outlined : Icons.sports_soccer_outlined, color: m.isCompleted ? AppColors.textSecondary : AppColors.primary),
                ),
                title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text('${DateFormat('dd/MM/yyyy · HH:mm').format(m.startsAt)} · ${m.venueName}'),
                ),
                trailing: m.isCompleted
                    ? Text('${m.scoreA ?? '-'}-${m.scoreB ?? '-'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))
                    : const Icon(Icons.chevron_right_rounded),
              ),
            );
          },
        ),
      ),
    );
  }
}
