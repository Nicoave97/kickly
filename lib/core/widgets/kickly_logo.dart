import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class KicklyLogo extends StatelessWidget {
  final double fontSize;
  final bool showWordmark;
  const KicklyLogo({super.key, this.fontSize = 30, this.showWordmark = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/brand/kickly_icon.svg',
          width: fontSize * 1.08,
          height: fontSize * 1.08,
          semanticsLabel: 'Kickly',
        ),
        if (showWordmark) ...[
          SizedBox(width: fontSize * .25),
          Text(
            'Kickly',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
            ),
          ),
        ],
      ],
    );
  }
}
