import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../repositories/match_repository.dart';

class InvitePage extends StatefulWidget {
  final String inviteCode;
  const InvitePage({super.key, required this.inviteCode});

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  late final future = MatchRepository().getMatchByInviteCode(widget.inviteCode);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Invito non valido o partita non disponibile.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final match = snapshot.data!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/match/${match.id}');
          });
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
