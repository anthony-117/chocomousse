import 'package:chocomousse/features/destination/data/models.dart';
import 'package:chocomousse/features/destination/presentation/place_details_screen.dart';
import 'package:chocomousse/features/destination/presentation/places_screen.dart';
import 'package:chocomousse/features/destination/presentation/widgets/pin_map.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'fakes.dart';

void main() {
  group('PlacesScreen', () {
    testWidgets('shows attractions with a map and switches to restaurants', (tester) async {
      usePhoneSize(tester);
      final repo = FakeDestinationRepository(
        attractions: PlacesResult(
          items: [
            place(),
            place(id: 'otm:N4', name: 'Pantheon', kind: 'Churches'),
          ],
          warnings: [],
        ),
        restaurants: PlacesResult(
          items: [place(id: 'otm:N9', name: 'Da Enzo', category: PlaceCategory.restaurant, kind: 'Restaurants')],
          warnings: [],
        ),
      );

      await tester.pumpWidget(host(const PlacesScreen(id: '3169070'), repo));
      await tester.pumpAndSettle();

      expect(find.text('Rome · Places'), findsOneWidget);
      expect(find.text('Colosseum'), findsOneWidget);
      expect(find.text('Pantheon'), findsOneWidget);
      expect(find.byType(PinMap), findsOneWidget);
      expect(find.bySemanticsLabel('Map preview with 2 places'), findsOneWidget);

      await tester.tap(find.text('Restaurants'));
      await tester.pumpAndSettle();

      expect(find.text('Da Enzo'), findsOneWidget);
      expect(find.text('Colosseum'), findsNothing);
      expect(repo.placesCalls, [PlaceCategory.attraction, PlaceCategory.restaurant]);
    });

    testWidgets('opens on the category from the link', (tester) async {
      usePhoneSize(tester);
      final repo = FakeDestinationRepository();

      await tester.pumpWidget(host(const PlacesScreen(id: '3169070', initialCategory: 'restaurant'), repo));
      await tester.pumpAndSettle();

      expect(repo.placesCalls, [PlaceCategory.restaurant]);
    });

    testWidgets('explains a missing API key instead of an empty list', (tester) async {
      usePhoneSize(tester);

      await tester.pumpWidget(host(const PlacesScreen(id: '3169070'), FakeDestinationRepository()));
      await tester.pumpAndSettle();

      expect(find.text(missingKeyWarning), findsOneWidget);
    });
  });

  group('PlaceDetailsScreen', () {
    testWidgets('shows description, address, hours, website and source', (tester) async {
      usePhoneSize(tester);
      final repo = FakeDestinationRepository(
        details: place(
          description: 'The largest ancient amphitheatre ever built.',
          address: 'Piazza del Colosseo, Rome',
          website: 'https://colosseo.it',
          openingHours: ['Monday: 09:00 – 19:15'],
          rating: 4.7,
        ),
      );

      await tester.pumpWidget(host(const PlaceDetailsScreen(placeId: 'otm:W3'), repo));
      await tester.pumpAndSettle();

      expect(find.text('Colosseum'), findsOneWidget);
      expect(find.text('Amphitheatres'), findsOneWidget);
      expect(find.text('★ 4.7 · 1.2K reviews'), findsOneWidget);
      expect(find.text('The largest ancient amphitheatre ever built.'), findsOneWidget);
      expect(find.text('Piazza del Colosseo, Rome'), findsOneWidget);
      expect(find.text('Monday: 09:00 – 19:15'), findsOneWidget);
      expect(find.text('Data: OpenTripMap'), findsOneWidget);
    });

    testWidgets('tapping the website copies it', (tester) async {
      usePhoneSize(tester);
      final copied = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied.add(call.arguments);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      final repo = FakeDestinationRepository(details: place(website: 'https://colosseo.it'));
      await tester.pumpWidget(host(const PlaceDetailsScreen(placeId: 'otm:W3'), repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('https://colosseo.it'));
      await tester.pumpAndSettle();

      expect(copied.single, {'text': 'https://colosseo.it'});
      expect(find.text('Link copied'), findsOneWidget);
    });

    testWidgets('shows a retry when the place cannot load', (tester) async {
      usePhoneSize(tester);

      await tester.pumpWidget(host(const PlaceDetailsScreen(placeId: 'otm:missing'), FakeDestinationRepository()));
      await tester.pumpAndSettle();

      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
