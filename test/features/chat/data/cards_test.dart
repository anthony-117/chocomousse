import 'package:chocomousse/features/chat/data/cards.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

AssistantCard _read(Map<String, Object?> json) => AssistantCard.fromJson(json.cast<String, dynamic>())!;

void main() {
  test('reads the envelope', () {
    final card = _read(hotelCardJson());
    expect(card.id, 'bk:1');
    expect(card.lat, 41.9);
    expect(card.lng, 12.49);
    expect(card.approximate, isFalse);
    expect(card.foundAt, DateTime.utc(2026, 11, 10, 19, 2, 5));
    expect(card.raw['kind'], 'hotel');
    expect(card.kind, 'hotel');
  });

  test('reads a plan card with the spec 010 summary fields', () {
    final card = _read(planCardJson()) as PlanCard;
    expect(card.plan.name, 'Rome, 5 days');
    expect(card.plan.status, PlanStatus.draft);
    expect(card.plan.destinationId, '3169070');
    expect(card.plan.adults, 2);
    expect(card.plan.tripBudget, 1200);
    expect(card.plan.pace, Pace.packed);
    expect(card.plan.lat, 41.9);
    expect(card.plan.lng, 12.49);
    expect(card.title, 'Rome, 5 days');
  });

  test('reads a flight card with its match, approximate', () {
    final card = _read(flightCardJson()) as FlightCard;
    expect(card.fare.originAirport, 'ORY');
    expect(card.fare.amount, 82);
    expect(card.match!.percent, 94);
    expect(card.approximate, isTrue);
    expect(card.title, 'ORY → FCO');
  });

  test('a null match stays null', () {
    expect((_read(flightCardJson(withMatch: false)) as FlightCard).match, isNull);
    expect((_read(hotelCardJson(withMatch: false)) as HotelCard).match, isNull);
    expect((_read(carCardJson()) as CarCard).match, isNull);
  });

  test('reads hotel, car and place cards', () {
    final hotel = _read(hotelCardJson()) as HotelCard;
    expect(hotel.hotel.name, 'Hotel Artemide');
    expect(hotel.match!.percent, 88);

    final car = _read(carCardJson()) as CarCard;
    expect(car.car.model, 'Fiat 600');
    expect(car.title, 'Fiat 600');

    final place = _read(placeCardJson()) as PlaceCard;
    expect(place.place.name, 'Colosseum');
    expect(place.place.rating, 4.7);
  });

  test('reads an event card, with and without a venue location', () {
    final event = _read(eventCardJson()) as EventCard;
    expect(event.event.name, 'Jazz at the Baths');
    expect(event.event.priceFrom, '35 EUR');
    expect(event.location!.lat, 41.879);

    final noVenue = _read(eventCardJson(withLocation: false)) as EventCard;
    expect(noVenue.location, isNull);
    expect(noVenue.approximate, isTrue);
  });

  test('reads a facts card', () {
    final facts = (_read(factsCardJson()) as FactsCard).facts;
    expect(facts.destination.name, 'Istanbul');
    expect(facts.destination.countryCode, 'TR');
    expect(facts.from, DateTime(2027, 5, 2));
    expect(facts.weather!.summary, 'Mild, some rain');
    expect(facts.weather!.maxC, 21);
    expect(facts.weather!.rainChance, 40);
    expect(facts.visa!.label, 'e-Visa');
    expect(facts.currency!.to, 'TRY');
    expect(facts.currency!.rate, 34.1);
    expect(facts.safety!.level, 2);
    expect(facts.holidays.single.name, 'Labour Day');
  });

  test('a facts card with every part missing still reads', () {
    final json = factsCardJson();
    final item = (json['item']! as Map<String, Object?>)
      ..['weather'] = null
      ..['visa'] = null
      ..['currency'] = null
      ..['safety'] = null
      ..['holidays'] = <Object>[];
    final facts = (_read({...json, 'item': item}) as FactsCard).facts;
    expect([facts.weather, facts.visa, facts.currency, facts.safety], everyElement(isNull));
    expect(facts.holidays, isEmpty);
  });

  test('skips an unknown kind and a broken item', () {
    expect(AssistantCard.fromJson(envelope('train', 't1', {'id': 't1'}).cast()), isNull);
    expect(AssistantCard.fromJson(envelope('hotel', 'bk:1', {'id': 'bk:1'}).cast()), isNull);
    expect(AssistantCard.fromJson({'kind': 'hotel', 'id': 'bk:1'}), isNull);

    final cards = readCards([hotelCardJson(), envelope('train', 't1', {}), placeCardJson()]);
    expect(cards.map((c) => c.kind), ['hotel', 'place']);
  });
}
