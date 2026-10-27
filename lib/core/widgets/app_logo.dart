import 'package:chocomousse/app/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The approved v0.3 logo mark.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({this.size = 40, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset('assets/brand/logo_mark.svg', width: size, height: size, semanticsLabel: 'TravelGenie');
  }
}

/// Mark + "travelgenie." wordmark used in headers.
class AppWordmark extends StatelessWidget {
  const AppWordmark({this.markSize = 40, this.fontSize = 22, super.key});

  final double markSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: AppColors.text);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLogoMark(size: markSize),
        const SizedBox(width: 10),
        Text.rich(
          TextSpan(
            style: base,
            children: const [
              TextSpan(text: 'travel'),
              TextSpan(
                text: 'genie',
                style: TextStyle(color: AppColors.primary),
              ),
              TextSpan(
                text: '.',
                style: TextStyle(color: AppColors.accent),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
