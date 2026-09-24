import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class KicklyAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String fallbackLocation;
  final List<Widget>? actions;

  const KicklyAppBar({
    super.key,
    required this.title,
    this.fallbackLocation = '/',
    this.actions,
  });

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(fallbackLocation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        tooltip: 'Indietro',
        onPressed: () => _back(context),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: Text(title),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
