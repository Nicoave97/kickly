import 'package:flutter/material.dart';

class ResponsivePage extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool scrollable;

  const ResponsivePage({
    super.key,
    required this.child,
    this.maxWidth = 1180,
    this.padding,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width >= 1100 ? 32.0 : width >= 700 ? 24.0 : 16.0;
    final effectivePadding = padding ?? EdgeInsets.fromLTRB(horizontal, 20, horizontal, 32);
    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: effectivePadding, child: child),
      ),
    );
    if (!scrollable) return content;
    return SingleChildScrollView(child: content);
  }
}

class PageReveal extends StatelessWidget {
  final Widget child;
  final Duration duration;
  const PageReveal({super.key, required this.child, this.duration = const Duration(milliseconds: 260)});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 10 * (1 - value)), child: child),
      ),
      child: child,
    );
  }
}
