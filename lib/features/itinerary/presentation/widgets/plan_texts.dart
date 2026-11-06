import 'package:chocomousse/features/destination/presentation/widgets/offers.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:intl/intl.dart';

final _dayMonth = DateFormat('d MMM');
final _weekday = DateFormat('EEE d MMM');

/// "10 – 14 Apr", or "28 Apr – 2 May" across months.
String planDates(DateTime from, DateTime to) => from.month == to.month && from.year == to.year
    ? '${from.day} – ${_dayMonth.format(to)}'
    : '${_dayMonth.format(from)} – ${_dayMonth.format(to)}';

String adults(int n) => n == 1 ? '1 adult' : '$n adults';

String nights(int n) => n == 1 ? '1 night' : '$n nights';

/// "10 – 14 Apr · 1 adult · Draft, saved" (I1).
String planSubtitle(Plan plan) =>
    '${planDates(plan.from, plan.to)} · ${adults(plan.adults)} · ${plan.status.label}, saved';

/// "2h", "1h 30", "45 min".
String itemDuration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final rest = minutes % 60;
  return rest == 0 ? '${minutes ~/ 60}h' : '${minutes ~/ 60}h ${rest.toString().padLeft(2, '0')}';
}

String _km(double km) => km < 10 ? km.toStringAsFixed(1) : km.round().toString();

String kindLabel(ItemKind kind) => switch (kind) {
  ItemKind.arrival => 'Arrival',
  ItemKind.departure => 'Departure',
  ItemKind.sight => 'Sight',
  ItemKind.nature => 'Nature',
  ItemKind.restaurant => 'Restaurant',
  ItemKind.nightlife => 'Evening out',
  ItemKind.event => 'Event',
  ItemKind.freeTime => 'Free time',
  ItemKind.other => 'Visit',
};

/// "Sight · 2h · 1.1 km walk from the hotel", "Event · 2h · from $38", "Back at the hotel or wander nearby".
String itemDetails(PlanItem item, {required bool first}) {
  if (item.kind == ItemKind.freeTime) return 'Back at the hotel or wander nearby';
  final price = item.price;
  return [
    kindLabel(item.kind),
    itemDuration(item.minutes),
    if (item.walkKm > 0) '${_km(item.walkKm)} km walk${first ? ' from the hotel' : ''}',
    if (price != null) 'from ${formatMoney(price.amount, price.currency)}',
  ].join(' · ');
}

/// "Fri 11 Apr · Sunny, 21° / 12° · walking 6.4 km".
String dayDetails(PlanDay day) {
  final weather = day.weather;
  return [
    _weekday.format(day.date),
    if (weather != null) '${weather.summary}, ${weather.maxC.round()}° / ${weather.minC.round()}°',
    if (day.walkKm > 0) 'walking ${_km(day.walkKm)} km',
  ].join(' · ');
}

/// "Day 2 · Fri 11 Apr" over the day's title in the wide day list (W4).
String dayLabel(PlanDay day) => 'Day ${day.number} · ${_weekday.format(day.date)}';

/// The day's own title without its "Day 2 · " prefix, for the wide day list.
String dayTopic(PlanDay day) {
  final prefix = 'Day ${day.number} · ';
  return day.title.startsWith(prefix) ? day.title.substring(prefix.length) : day.title;
}
