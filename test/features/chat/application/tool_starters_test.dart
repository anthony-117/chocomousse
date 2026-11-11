import 'package:chocomousse/features/chat/application/tool_starters.dart';
import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final full = ChatTrip(
    destinationId: '3169070',
    destinationName: 'Rome',
    from: DateTime(2027, 4, 10),
    to: DateTime(2027, 4, 14),
    adults: 2,
    originId: '276781',
    originName: 'Beirut',
  );

  test('each tool starts from the full trip', () {
    expect(
      {for (final tool in Tool.values) tool: toolStarter(tool, full)},
      {
        Tool.planTrip: 'Plan 5 days in Rome for 2 adults',
        Tool.flights: 'Find flights from Beirut to Rome on 10 Apr',
        Tool.hotels: 'Find hotels in Rome for 10 – 14 Apr',
        Tool.carRental: 'Rent a car in Rome from 10 Apr to 14 Apr',
        Tool.places: 'Top sights in Rome',
        Tool.events: "What's on in Rome 10 – 14 Apr",
        Tool.travelInfo: 'Visa and weather for Rome',
        Tool.preferences: 'Show my travel preferences',
      },
    );
  });

  test('an empty trip leaves every value as "…"', () {
    expect(
      {for (final tool in Tool.values) tool: toolStarter(tool, ChatTrip.empty)},
      {
        Tool.planTrip: 'Plan … days in … for …',
        Tool.flights: 'Find flights from … to … on …',
        Tool.hotels: 'Find hotels in … for … – …',
        Tool.carRental: 'Rent a car in … from … to …',
        Tool.places: 'Top sights in …',
        Tool.events: "What's on in … … – …",
        Tool.travelInfo: 'Visa and weather for …',
        Tool.preferences: 'Show my travel preferences',
      },
    );
  });

  test('one adult, a trip across months, and a start without an end', () {
    final trip = ChatTrip(destinationName: 'Lisbon', from: DateTime(2027, 4, 28), to: DateTime(2027, 5, 2), adults: 1);
    expect(toolStarter(Tool.planTrip, trip), 'Plan 5 days in Lisbon for 1 adult');
    expect(toolStarter(Tool.hotels, trip), 'Find hotels in Lisbon for 28 Apr – 2 May');
    expect(
      toolStarter(Tool.carRental, ChatTrip(destinationName: 'Lisbon', from: DateTime(2027, 4, 28))),
      'Rent a car in Lisbon from 28 Apr to …',
    );
  });

  test('both ends of a trip count as days', () {
    expect(tripDays(DateTime(2027, 4, 10), DateTime(2027, 4, 10)), 1);
    expect(tripDays(DateTime(2027, 4, 10, 23), DateTime(2027, 4, 11, 1)), 2);
  });
}
