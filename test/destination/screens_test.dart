import 'package:chocomousse/app/theme/app_theme.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/destination/presentation/overview_screen.dart';
import 'package:chocomousse/features/destination/presentation/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Widget _host(Widget screen, FakeDestinationRepository repo) => ProviderScope(
  overrides: [destinationRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: screen),
  ),
);

void main() {
  setUp(() {
    // Phone-sized surface (design 03/04).
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..physicalSize = const Size(390, 1400)
      ..devicePixelRatio = 1;
  });
  tearDown(() => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset());

  testWidgets('search waits for typing to pause, then lists matching cities', (tester) async {
    final repo = FakeDestinationRepository();
    await tester.pumpWidget(_host(const SearchScreen(), repo));

    await tester.enterText(find.byType(TextField), 'ro');
    await tester.pump(const Duration(milliseconds: 100));
    expect(repo.searches, isEmpty);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(repo.searches, ['ro']);
    expect(find.text('Rome'), findsOneWidget);
    expect(find.text('Lazio, Italy 🇮🇹'), findsOneWidget);
    expect(find.text('TRAVELLING WITH'), findsOneWidget);
  });

  testWidgets('overview shows facts, keeps going when a section failed, and explains missing keys', (tester) async {
    await tester.pumpWidget(_host(const OverviewScreen(id: '3169070'), FakeDestinationRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Rome'), findsOneWidget);
    expect(find.text('Visa required'), findsOneWidget);
    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('21° / 8°'), findsOneWidget);
    expect(find.text('Easter Monday'), findsOneWidget);
    expect(find.text('Exchange rate is unavailable right now.'), findsOneWidget);
    expect(find.textContaining('OPENTRIPMAP_API_KEY'), findsOneWidget);
  });
}
