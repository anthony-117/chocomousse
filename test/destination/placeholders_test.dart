import 'dart:async';

import 'package:chocomousse/core/widgets/skeleton.dart';
import 'package:chocomousse/features/destination/data/models.dart';
import 'package:chocomousse/features/destination/presentation/overview_screen.dart';
import 'package:chocomousse/features/destination/presentation/place_details_screen.dart';
import 'package:chocomousse/features/destination/presentation/places_screen.dart';
import 'package:chocomousse/features/destination/presentation/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'fakes.dart';

/// A backend that never answers.
class _SlowRepository extends FakeDestinationRepository {
  @override
  Future<DestinationOverview> overview(
    String id, {
    required String passport,
    required String currency,
    required DateTime from,
    required DateTime to,
  }) => Completer<DestinationOverview>().future;
}

/// A backend that is down.
class _DownRepository extends FakeDestinationRepository {
  _DownRepository() : super(overviewError: StateError('down'));

  @override
  Future<List<DestinationSummary>> search(String query) async => throw StateError('down');

  @override
  Future<DestinationSummary> destination(String id) async => throw StateError('down');

  @override
  Future<PlacesResult> places(String id, PlaceCategory category) async => throw StateError('down');
}

void main() {
  testWidgets('overview shows its layout with empty boxes while loading', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(host(const OverviewScreen(id: '3169070'), _SlowRepository()));
    await tester.pump();

    expect(find.text('Weather'), findsOneWidget);
    expect(find.text('Top attractions'), findsOneWidget);
    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('overview keeps its layout when the backend is down, and retries on request', (tester) async {
    usePhoneSize(tester);
    final repo = _DownRepository();
    await tester.pumpWidget(host(const OverviewScreen(id: '3169070'), repo));
    await tester.pumpAndSettle();

    for (final title in ['Weather', 'Currency', 'Visa', 'Safety', 'Holidays', 'Country', 'Top attractions']) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.byType(SkeletonBox), findsWidgets);
    expect(repo.overviewCalls, hasLength(1));

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(repo.overviewCalls, hasLength(2));
  });

  testWidgets('overview placeholder fits a wide screen', (tester) async {
    tester.view
      ..physicalSize = const Size(1280, 1400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(const OverviewScreen(id: '3169070'), _DownRepository()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Weather'), findsOneWidget);
  });

  testWidgets('places keeps its filters, with empty boxes, when the backend is down', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(host(const PlacesScreen(id: '3169070'), _DownRepository()));
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceChip), findsWidgets);
    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('place details shows empty boxes when the backend is down', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(host(const PlaceDetailsScreen(placeId: 'otm:missing'), FakeDestinationRepository()));
    await tester.pumpAndSettle();

    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('search shows empty rows when the backend is down', (tester) async {
    usePhoneSize(tester);
    await tester.pumpWidget(host(const SearchScreen(), _DownRepository()));
    await tester.enterText(find.byType(TextField), 'ro');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('TRAVELLING WITH'), findsOneWidget);
  });
}
