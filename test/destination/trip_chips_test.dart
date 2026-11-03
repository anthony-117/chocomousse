import 'package:chocomousse/features/destination/data/models.dart';
import 'package:chocomousse/features/destination/presentation/widgets/trip_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'fakes.dart';

const _countries = [
  CountryOption(code: 'FR', name: 'France', flag: null, currencies: ['EUR']),
  CountryOption(code: 'LB', name: 'Lebanon', flag: null, currencies: ['LBP']),
  CountryOption(code: 'AQ', name: 'Antarctica', flag: null, currencies: []),
];

void main() {
  testWidgets('shows passport, currency and dates', (tester) async {
    await tester.pumpWidget(host(const TripChips(), FakeDestinationRepository()));

    expect(find.text('Passport: LB'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    expect(find.textContaining(' – '), findsOneWidget);
    expect(find.textContaining('adults'), findsNothing); // only hotels ask for adults
  });

  testWidgets('adults chip changes the number of adults', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(host(const TripChips(showPassport: false, showAdults: true), FakeDestinationRepository()));
    expect(find.text('Passport: LB'), findsNothing);

    await tester.tap(find.text('2 adults · 1 room'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Fewer adults'));
    await tester.pumpAndSettle();
    expect(find.text('1 adult · 1 room'), findsOneWidget);
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove)).onPressed, isNull);

    await tester.tap(find.byTooltip('More adults'));
    await tester.pump();
    await tester.tap(find.byTooltip('More adults'));
    await tester.pumpAndSettle();
    expect(find.text('3 adults · 1 room'), findsOneWidget);
  });

  testWidgets('passport picker filters countries and updates the chip', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(host(const TripChips(), FakeDestinationRepository(countryOptions: _countries)));

    await tester.tap(find.text('Passport: LB'));
    await tester.pumpAndSettle();
    expect(find.text('Your passport'), findsOneWidget);
    expect(find.text('Antarctica'), findsOneWidget); // every country has a passport code

    await tester.enterText(find.byType(TextField), 'fra');
    await tester.pumpAndSettle();
    expect(find.text('Lebanon'), findsNothing);

    await tester.tap(find.text('France'));
    await tester.pumpAndSettle();
    expect(find.text('Passport: FR'), findsOneWidget);
  });

  testWidgets('currency picker hides countries without a currency', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(host(const TripChips(), FakeDestinationRepository(countryOptions: _countries)));

    await tester.tap(find.text('USD'));
    await tester.pumpAndSettle();
    expect(find.text('Antarctica'), findsNothing);

    await tester.tap(find.text('Lebanon'));
    await tester.pumpAndSettle();
    expect(find.text('LBP'), findsOneWidget);
  });
}
