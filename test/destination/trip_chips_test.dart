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
