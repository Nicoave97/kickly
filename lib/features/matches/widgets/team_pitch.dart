import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/match_model.dart';
import '../../../models/match_participant.dart';

class TeamPitch extends StatefulWidget {
  final MatchModel match;
  final List<MatchParticipant> teamA;
  final List<MatchParticipant> teamB;
  final List<MatchParticipant> unassigned;
  final bool editable;
  final Future<void> Function(MatchParticipant player, String team, double x, double y) onDrop;

  const TeamPitch({
    super.key,
    required this.match,
    required this.teamA,
    required this.teamB,
    required this.unassigned,
    required this.editable,
    required this.onDrop,
  });

  @override
  State<TeamPitch> createState() => _TeamPitchState();
}

class _TeamPitchState extends State<TeamPitch> {
  final fieldKey = GlobalKey();

  static const formation = <Offset>[
    Offset(.10, .50),
    Offset(.24, .28),
    Offset(.24, .72),
    Offset(.37, .34),
    Offset(.37, .66),
    Offset(.44, .50),
    Offset(.31, .50),
  ];

  Offset _fallback(String team, int index) {
    final base = formation[index % formation.length];
    return team == 'a' ? base : Offset(1 - base.dx, 1 - base.dy);
  }

  Future<void> _accept(DragTargetDetails<MatchParticipant> details) async {
    if (!widget.editable) return;
    final context = fieldKey.currentContext;
    if (context == null) return;
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(details.offset);
    final size = box.size;
    var x = (local.dx / size.width).clamp(.05, .95).toDouble();
    final y = (local.dy / size.height).clamp(.10, .90).toDouble();
    final team = x < .5 ? 'a' : 'b';
    x = team == 'a' ? x.clamp(.06, .46).toDouble() : x.clamp(.54, .94).toDouble();
    await widget.onDrop(details.data, team, x, y);
  }

  @override
  Widget build(BuildContext context) {
    final players = [...widget.teamA, ...widget.teamB];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _TeamLabel(
                name: widget.match.teamAName,
                count: widget.teamA.length,
                color: AppColors.redTeam,
                alignment: Alignment.centerLeft,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TeamLabel(
                name: widget.match.teamBName,
                count: widget.teamB.length,
                color: AppColors.blueTeam,
                alignment: Alignment.centerRight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = math.max(260.0, math.min(500.0, width / 1.55));
            return DragTarget<MatchParticipant>(
              onWillAcceptWithDetails: (_) => widget.editable,
              onAcceptWithDetails: _accept,
              builder: (context, candidates, rejected) {
                return AnimatedContainer(
                  key: fieldKey,
                  duration: const Duration(milliseconds: 140),
                  height: height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: candidates.isEmpty
                        ? null
                        : [BoxShadow(color: AppColors.primary.withValues(alpha: .18), blurRadius: 18)],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      children: [
                        const Positioned.fill(child: CustomPaint(painter: _PitchPainter())),
                        Positioned(
                          left: 12,
                          top: 10,
                          child: _HalfBadge(name: widget.match.teamAName, color: AppColors.redTeam),
                        ),
                        Positioned(
                          right: 12,
                          bottom: 10,
                          child: _HalfBadge(name: widget.match.teamBName, color: AppColors.blueTeam),
                        ),
                        ...players.asMap().entries.map((entry) {
                          final player = entry.value;
                          final teamList = player.team == 'a' ? widget.teamA : widget.teamB;
                          final teamIndex = teamList.indexWhere((p) => p.userId == player.userId);
                          final fallback = _fallback(player.team, teamIndex < 0 ? entry.key : teamIndex);
                          final x = player.positionX ?? fallback.dx;
                          final y = player.positionY ?? fallback.dy;
                          const chipWidth = 92.0;
                          const chipHeight = 56.0;
                          return Positioned(
                            left: (x * width - chipWidth / 2).clamp(4.0, width - chipWidth - 4).toDouble(),
                            top: (y * height - chipHeight / 2).clamp(4.0, height - chipHeight - 4).toDouble(),
                            child: _PitchPlayer(
                              player: player,
                              teamColor: player.team == 'a' ? AppColors.redTeam : AppColors.blueTeam,
                              draggable: widget.editable,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        if (widget.unassigned.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Da assegnare', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.unassigned
                .map((player) => _UnassignedPlayer(player: player, draggable: widget.editable))
                .toList(),
          ),
          if (widget.editable) ...[
            const SizedBox(height: 8),
            const Text(
              'Trascina un giocatore sul campo. La metà scelta determina la squadra.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ],
      ],
    );
  }
}

class _TeamLabel extends StatelessWidget {
  final String name;
  final int count;
  final Color color;
  final Alignment alignment;
  const _TeamLabel({required this.name, required this.count, required this.color, required this.alignment});

  @override
  Widget build(BuildContext context) => Align(
        alignment: alignment,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 7),
            Flexible(child: Text('$name · $count', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
          ],
        ),
      );
}

class _HalfBadge extends StatelessWidget {
  final String name;
  final Color color;
  const _HalfBadge({required this.name, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xB807111D), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _PitchPlayer extends StatelessWidget {
  final MatchParticipant player;
  final Color teamColor;
  final bool draggable;
  const _PitchPlayer({required this.player, required this.teamColor, required this.draggable});

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      width: 92,
      height: 56,
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: teamColor, width: 2),
              color: const Color(0xFF102235),
              image: player.profile.avatarUrl == null ? null : DecorationImage(image: NetworkImage(player.profile.avatarUrl!), fit: BoxFit.cover),
            ),
            alignment: Alignment.center,
            child: player.profile.avatarUrl == null
                ? Text(player.profile.fullName.characters.first.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800))
                : null,
          ),
          const SizedBox(height: 3),
          Container(
            constraints: const BoxConstraints(maxWidth: 90),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xD907111D), borderRadius: BorderRadius.circular(7)),
            child: Text(
              player.profile.fullName.split(' ').first,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (!draggable) return child;
    return Draggable<MatchParticipant>(
      data: player,
      feedback: Material(color: Colors.transparent, child: Opacity(opacity: .9, child: child)),
      childWhenDragging: Opacity(opacity: .28, child: child),
      child: MouseRegion(cursor: SystemMouseCursors.grab, child: child),
    );
  }
}

class _UnassignedPlayer extends StatelessWidget {
  final MatchParticipant player;
  final bool draggable;
  const _UnassignedPlayer({required this.player, required this.draggable});

  @override
  Widget build(BuildContext context) {
    final child = Chip(
      avatar: CircleAvatar(
        backgroundImage: player.profile.avatarUrl == null ? null : NetworkImage(player.profile.avatarUrl!),
        child: player.profile.avatarUrl == null ? Text(player.profile.fullName.characters.first.toUpperCase()) : null,
      ),
      label: Text(player.profile.fullName),
      side: const BorderSide(color: AppColors.border),
      backgroundColor: AppColors.surfaceAlt,
    );
    if (!draggable) return child;
    return Draggable<MatchParticipant>(
      data: player,
      feedback: Material(color: Colors.transparent, child: child),
      childWhenDragging: Opacity(opacity: .35, child: child),
      child: MouseRegion(cursor: SystemMouseCursors.grab, child: child),
    );
  }
}

class _PitchPainter extends CustomPainter {
  const _PitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..shader = const LinearGradient(
      colors: [Color(0xFF123D2A), Color(0xFF0D3023)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final stripe = Paint()..color = Colors.white.withValues(alpha: .025);
    final stripeWidth = size.width / 8;
    for (var i = 0; i < 8; i += 2) {
      canvas.drawRect(Rect.fromLTWH(i * stripeWidth, 0, stripeWidth, size.height), stripe);
    }

    final line = Paint()
      ..color = Colors.white.withValues(alpha: .62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final inset = math.min(size.width, size.height) * .035;
    final field = Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2);
    canvas.drawRRect(RRect.fromRectAndRadius(field, const Radius.circular(6)), line);
    canvas.drawLine(Offset(size.width / 2, inset), Offset(size.width / 2, size.height - inset), line);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), math.min(size.width, size.height) * .12, line);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 2.2, Paint()..color = Colors.white.withValues(alpha: .72));

    final boxW = size.width * .13;
    final boxH = size.height * .46;
    canvas.drawRect(Rect.fromLTWH(inset, (size.height - boxH) / 2, boxW, boxH), line);
    canvas.drawRect(Rect.fromLTWH(size.width - inset - boxW, (size.height - boxH) / 2, boxW, boxH), line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
