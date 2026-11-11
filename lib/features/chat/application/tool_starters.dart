import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:chocomousse/features/itinerary/presentation/widgets/plan_texts.dart';
import 'package:intl/intl.dart';

/// The tools of the "+" sheet (M4) and the web menu, in the sheet's order (spec 008 FR-029).
enum Tool {
  planTrip('Plan a trip', 'Day by day'),
  flights('Flights', 'Best fares'),
  hotels('Hotels', 'Ranked for you'),
  carRental('Car rental', 'Pick-up & return'),
  places('Places', 'Sights & food'),
  events('Events', 'Shows & games'),
  travelInfo('Travel info', 'Visa & weather'),
  preferences('My preferences', 'Budget & pace');

  Tool(this.label, this.detail);

  final String label;

  /// The second line under the label.
  final String detail;
}

/// What a value the trip doesn't have yet reads as, for the traveller to fill in.
const kUnknown = '…';

final _dayMonth = DateFormat('d MMM');

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// The days of a trip, both ends counted: 10 – 14 Apr is 5 days.
int tripDays(DateTime from, DateTime to) => _day(to).difference(_day(from)).inDays + 1;

/// The message a tool puts in the composer, built from the trip chip (spec 008 FR-030). It is never sent by itself;
/// a value the trip doesn't have is left as "…".
String toolStarter(Tool tool, ChatTrip trip) {
  final city = trip.destinationName ?? kUnknown;
  final origin = trip.originName ?? kUnknown;
  final from = trip.from;
  final to = trip.to;
  final start = from == null ? kUnknown : _dayMonth.format(from);
  final end = to == null ? kUnknown : _dayMonth.format(to);
  final range = from != null && to != null ? planDates(from, to) : '$start – $end';
  final days = from != null && to != null ? '${tripDays(from, to)}' : kUnknown;
  final people = switch (trip.adults) {
    final n? => adults(n),
    null => kUnknown,
  };
  return switch (tool) {
    Tool.planTrip => 'Plan $days days in $city for $people',
    Tool.flights => 'Find flights from $origin to $city on $start',
    Tool.hotels => 'Find hotels in $city for $range',
    Tool.carRental => 'Rent a car in $city from $start to $end',
    Tool.places => 'Top sights in $city',
    Tool.events => "What's on in $city $range",
    Tool.travelInfo => 'Visa and weather for $city',
    Tool.preferences => 'Show my travel preferences',
  };
}
