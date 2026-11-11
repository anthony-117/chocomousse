import 'package:chocomousse/app/theme/app_icons.dart';
import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _dayMonth = DateFormat('d MMM');

/// The travel facts as lines: (icon, title, text). A part the API left out is left out here.
List<(AppIcons, String, String)> factsLines(TravelFacts facts, {bool full = false}) {
  final weather = facts.weather;
  final visa = facts.visa;
  final currency = facts.currency;
  final safety = facts.safety;
  final holidays = facts.holidays;
  return [
    if (weather != null)
      (
        AppIcons.sun,
        'Weather',
        [
          if (weather.maxC != null && weather.minC != null) '${weather.maxC}° / ${weather.minC}°',
          weather.summary,
          if (full && weather.rainChance != null) '${weather.rainChance}% chance of rain',
        ].join(' · '),
      ),
    if (visa != null) (AppIcons.globe, 'Visa', visa.label),
    if (currency != null)
      (
        AppIcons.wallet,
        'Currency',
        '1 ${currency.from} = ${NumberFormat('0.00').format(currency.rate)} ${currency.to}',
      ),
    if (safety != null) (AppIcons.check, 'Safety', full ? '${safety.label}. ${safety.summary}' : safety.label),
    if (holidays.isNotEmpty)
      (
        AppIcons.calendar,
        'Holidays',
        full
            ? holidays.map((h) => '${_dayMonth.format(h.date)} · ${h.name}').join('\n')
            : [
                '${_dayMonth.format(holidays.first.date)} · ${holidays.first.name}',
                if (holidays.length > 1) '+${holidays.length - 1} more',
              ].join(' '),
      ),
  ];
}

/// Weather, visa, currency, safety and holidays for a trip (spec 008 US2), each with its icon. [full] adds the rain,
/// the safety summary and every holiday, for the Details pane.
class FactsRows extends StatelessWidget {
  const FactsRows({required this.facts, this.full = false, super.key});

  final TravelFacts facts;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final lines = factsLines(facts, full: full);
    if (lines.isEmpty) {
      return Text('No travel facts for these dates.', style: AppText.small.copyWith(color: palette.textSecondary));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (icon, title, text) in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIcon(icon, size: 18, color: palette.brandPrimary),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 80,
                  child: Text(title, style: AppText.smallStrong.copyWith(color: palette.textSecondary)),
                ),
                Expanded(
                  child: Text(text, style: AppText.small.copyWith(color: palette.textPrimary)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
