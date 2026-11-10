import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/data/plan_repository.dart';
import 'package:chocomousse/features/itinerary/presentation/my_plans_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'fakes.dart';
import 'plan_app.dart';

FakePlanRepository _three() => FakePlanRepository(
  plans: [
    Plan.fromJson(planJson(name: 'Lisbon, 3 days')),
    Plan.fromJson(planJson(id: 'p2', name: 'Rome with Maya', status: 'planned')),
    Plan.fromJson(planJson(id: 'p3')),
  ],
);

List<String> _names(WidgetTester tester) =>
    tester.widgetList<PlanCard>(find.byType(PlanCard)).map((c) => c.plan.name).toList();

void main() {
  group('My plans (I5)', () {
    testWidgets('lists every plan, newest change first, and filters by status', (tester) async {
      usePhoneSize(tester);
      final app = PlanApp(tester, plans: _three());
      await app.open('/plans');

      expect(find.text('My plans'), findsOneWidget);
      expect(_names(tester), ['Rome, 5 days', 'Rome with Maya', 'Lisbon, 3 days']);
      expect(find.text('PLANNED'), findsOneWidget);
      expect(find.text(r'10 – 14 Apr · $939'), findsNWidgets(3));
      expect(find.text('91% match'), findsNWidgets(3));
      expect(find.text('3 of 50 plans'), findsOneWidget);
      expect(find.text('Plan a new trip'), findsOneWidget);

      await app.tapText('Drafts');
      expect(_names(tester), ['Rome, 5 days', 'Lisbon, 3 days']);

      await app.tapText('Planned');
      expect(_names(tester), ['Rome with Maya']);
    });

    testWidgets('a plan opens its itinerary', (tester) async {
      usePhoneSize(tester, height: 2000);
      final app = PlanApp(tester, plans: _three());
      await app.open('/plans');

      await app.tapText('Rome with Maya');

      expect(find.text('10 – 14 Apr · 1 adult · Planned, saved'), findsOneWidget);
    });

    testWidgets('with no plans, says how to build one with a link to Discover', (tester) async {
      usePhoneSize(tester);
      final app = PlanApp(tester, plans: FakePlanRepository(plans: []));
      await app.open('/plans');

      expect(find.text('No plans yet'), findsOneWidget);
      await app.tapText('Discover');
      expect(app.location, '/discover');
    });

    testWidgets('a failed list shows Try again over still placeholders', (tester) async {
      usePhoneSize(tester);
      final plans = _three()
        ..failListWith = DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError);
      final app = PlanApp(tester, plans: plans);
      await app.open('/plans');

      expect(find.text('Cannot reach the TravelGenie server.'), findsOneWidget);
      expect(find.byType(PlanCardPlaceholders), findsOneWidget);

      await app.tapText('Try again');
      expect(find.byType(PlanCard), findsNWidgets(3));
    });

    testWidgets('shows three columns on wide screens (W7)', (tester) async {
      useDesktopSize(tester);
      final app = PlanApp(tester, plans: _three());
      await app.open('/plans');

      final rects = find.byType(PlanCard).evaluate().map((e) => tester.getRect(find.byWidget(e.widget))).toList();
      expect(rects.map((r) => r.top).toSet(), hasLength(1));
      expect(rects.first.width, lessThan(450));
    });
  });

  group('Plan actions (I6)', () {
    Future<void> openActions(PlanApp app, String name) async {
      final card = find.ancestor(of: find.text(name), matching: find.byType(PlanCard));
      await app.tap(find.descendant(of: card, matching: find.byTooltip('Plan actions')));
    }

    testWidgets('rename takes 1 to 60 characters and shows the new name', (tester) async {
      usePhoneSize(tester);
      final app = PlanApp(tester, plans: _three());
      await app.open('/plans');

      await openActions(app, 'Rome, 5 days');
      expect(find.text('Mark as planned'), findsOneWidget);
      expect(find.text('Delete plan'), findsOneWidget);
      await app.tapText('Rename');

      final field = find.byType(TextField);
      expect(tester.widget<TextField>(field).maxLength, 60);
      await tester.enterText(field, '   ');
      await tester.pump();
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save')).onPressed, isNull);

      await tester.enterText(field, 'Spring in Rome');
      await app.tapText('Save');

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Spring in Rome'), findsOneWidget);
      expect(app.plans.calls, contains('rename p3 Spring in Rome'));
    });

    testWidgets("a refused name shows the API's reason in the dialog", (tester) async {
      usePhoneSize(tester);
      final app = PlanApp(tester, plans: _three());
      await app.open('/plans');

      await openActions(app, 'Rome, 5 days');
      await app.tapText('Rename');
      app.plans.failWith = const PlanFieldError('name', 'Use 1 to 60 characters.');
      await app.tapText('Save');

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Use 1 to 60 characters.'), findsOneWidget);
    });

    testWidgets('mark as planned, then as a draft again', (tester) async {
      usePhoneSize(tester);
      final app = PlanApp(tester, plans: _three());
      await app.open('/plans');

      await openActions(app, 'Lisbon, 3 days');
      await app.tapText('Mark as planned');
      expect(find.text('PLANNED · EDITED TODAY'), findsOneWidget);

      await openActions(app, 'Lisbon, 3 days');
      await app.tapText('Mark as draft');
      expect(find.text('DRAFT · EDITED TODAY'), findsOneWidget);
      expect(app.plans.calls, containsAllInOrder(['status p1 planned', 'status p1 draft']));
    });

    testWidgets('delete asks first, then the plan is gone', (tester) async {
      usePhoneSize(tester);
      final app = PlanApp(tester, plans: _three());
      await app.open('/plans');

      await openActions(app, 'Rome with Maya');
      await app.tapText('Delete plan');
      expect(find.text('Delete Rome with Maya?'), findsOneWidget);
      await app.tapText('Cancel');
      expect(_names(tester), contains('Rome with Maya'));

      await openActions(app, 'Rome with Maya');
      await app.tapText('Delete plan');
      await app.tapText('Delete');

      expect(_names(tester), ['Rome, 5 days', 'Lisbon, 3 days']);
      expect(find.text('2 of 50 plans'), findsOneWidget);
      expect(app.plans.calls, contains('delete p2'));
    });

    testWidgets('a failed change says why', (tester) async {
      usePhoneSize(tester);
      final app = PlanApp(tester, plans: _three());
      await app.open('/plans');

      await openActions(app, 'Lisbon, 3 days');
      app.plans.failWith = const PlanNotFound();
      await app.tapText('Mark as planned');

      expect(find.text("This plan doesn't exist or isn't yours."), findsOneWidget);
    });
  });
}
