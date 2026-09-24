import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kickly_app_bar.dart';
import '../../core/widgets/responsive_page.dart';
import '../../models/match_model.dart';
import '../../repositories/match_repository.dart';

class CreateMatchPage extends StatefulWidget {
  const CreateMatchPage({super.key});
  @override
  State<CreateMatchPage> createState() => _CreateMatchPageState();
}

class _CreateMatchPageState extends State<CreateMatchPage> {
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController(text: 'Calcetto');
  final venue = TextEditingController();
  final address = TextEditingController();
  final maxPlayers = TextEditingController(text: '10');
  final benchSlots = TextEditingController(text: '4');
  final teamA = TextEditingController(text: 'Squadra A');
  final teamB = TextEditingController(text: 'Squadra B');
  DateTime date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay time = const TimeOfDay(hour: 21, minute: 0);
  TeamMode teamMode = TeamMode.admin;
  RatingMode ratingMode = RatingMode.everyone;
  bool loading = false;

  Future<void> pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (selected != null) setState(() => date = selected);
  }

  Future<void> pickTime() async {
    final selected = await showTimePicker(context: context, initialTime: time);
    if (selected != null) setState(() => time = selected);
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => loading = true);
    try {
      final startsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      final match = await MatchRepository().createMatch(CreateMatchInput(
        title: title.text,
        startsAt: startsAt,
        venueName: venue.text,
        venueAddress: address.text,
        maxPlayers: int.parse(maxPlayers.text),
        benchSlots: int.parse(benchSlots.text),
        teamMode: teamMode,
        ratingMode: ratingMode,
        teamAName: teamA.text,
        teamBName: teamB.text,
      ));
      if (mounted) context.go('/match/${match.id}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const KicklyAppBar(title: 'Crea partita', fallbackLocation: '/matches'),
      body: ResponsivePage(
        maxWidth: 840,
        scrollable: true,
        child: PageReveal(
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Nuova lobby', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                const Text('Imposta solo ciò che serve per organizzare la partita.', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 22),
                TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Nome partita'), validator: (v) => v == null || v.trim().isEmpty ? 'Campo richiesto' : null),
                const SizedBox(height: 12),
                TextFormField(controller: venue, decoration: const InputDecoration(labelText: 'Campo / struttura'), validator: (v) => v == null || v.trim().isEmpty ? 'Campo richiesto' : null),
                const SizedBox(height: 12),
                TextField(controller: address, decoration: const InputDecoration(labelText: 'Indirizzo (opzionale)')),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 560;
                    final dateButton = OutlinedButton.icon(onPressed: pickDate, icon: const Icon(Icons.calendar_month_outlined), label: Text(DateFormat('dd/MM/yyyy').format(date)));
                    final timeButton = OutlinedButton.icon(onPressed: pickTime, icon: const Icon(Icons.schedule_outlined), label: Text(time.format(context)));
                    if (!wide) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [dateButton, const SizedBox(height: 10), timeButton]);
                    return Row(children: [Expanded(child: dateButton), const SizedBox(width: 10), Expanded(child: timeButton)]);
                  },
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final a = TextFormField(controller: maxPlayers, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giocatori'), validator: (v) { final n = int.tryParse(v ?? ''); return n == null || n < 2 ? 'Minimo 2' : null; });
                    final b = TextFormField(controller: benchSlots, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Posti in panchina'), validator: (v) => int.tryParse(v ?? '') == null ? 'Numero non valido' : null);
                    if (constraints.maxWidth < 560) return Column(children: [a, const SizedBox(height: 10), b]);
                    return Row(children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);
                  },
                ),
                const SizedBox(height: 24),
                const Text('Squadre', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final a = TextField(controller: teamA, decoration: const InputDecoration(labelText: 'Nome squadra A'));
                    final b = TextField(controller: teamB, decoration: const InputDecoration(labelText: 'Nome squadra B'));
                    if (constraints.maxWidth < 560) return Column(children: [a, const SizedBox(height: 10), b]);
                    return Row(children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TeamMode>(
                  value: teamMode,
                  decoration: const InputDecoration(labelText: 'Assegnazione squadre'),
                  items: const [
                    DropdownMenuItem(value: TeamMode.admin, child: Text('Decide l’organizzatore')),
                    DropdownMenuItem(value: TeamMode.selfChoice, child: Text('Ogni giocatore sceglie')),
                  ],
                  onChanged: (v) => setState(() => teamMode = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RatingMode>(
                  value: ratingMode,
                  decoration: const InputDecoration(labelText: 'Votazioni post-partita'),
                  items: const [
                    DropdownMenuItem(value: RatingMode.off, child: Text('Disattivate')),
                    DropdownMenuItem(value: RatingMode.teammates, child: Text('Solo compagni')),
                    DropdownMenuItem(value: RatingMode.everyone, child: Text('Tutti i giocatori')),
                    DropdownMenuItem(value: RatingMode.opponents, child: Text('Solo avversari')),
                  ],
                  onChanged: (v) => setState(() => ratingMode = v!),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: loading ? null : submit,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(loading ? 'Creazione...' : 'Crea lobby'),
                  ),
                ),
                const SizedBox(height: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
