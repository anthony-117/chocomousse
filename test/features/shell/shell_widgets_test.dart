import 'package:chocomousse/app/router.dart';
import 'package:chocomousse/app/theme/app_theme.dart';
import 'package:chocomousse/app/theme/appearance.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/features/account/application/session.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:chocomousse/features/shell/account_menu.dart';
import 'package:chocomousse/features/shell/account_row.dart';
import 'package:chocomousse/features/shell/app_drawer.dart';
import 'package:chocomousse/features/shell/mobile_top_bar.dart';
import 'package:chocomousse/features/shell/search_chats_dialog.dart';
import 'package:chocomousse/features/shell/shell_nav.dart';
import 'package:chocomousse/features/shell/sidebar.dart';
import 'package:chocomousse/features/shell/widgets/sidebar_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../account/fakes.dart';
import '../../helpers.dart';

/// Hosts [shell] (built from the location) in a small router, so taps really navigate.
Future<GoRouter> _host(
  WidgetTester tester,
  Widget Function(String location) shell, {
  Size size = desktop,
  ThemeMode mode = ThemeMode.light,
  String initial = AppPaths.home,
}) async {
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      ShellRoute(
        builder: (context, state, child) => Scaffold(
          drawer: AppDrawer(location: state.uri.path),
          body: Row(
            children: [
              shell(state.uri.path),
              Expanded(child: child),
            ],
          ),
        ),
        routes: [
          for (final path in ['/', '/saved', '/discover', '/plans', '/profile', '/chat/:id'])
            GoRoute(path: path, builder: (context, state) => Text('page ${state.uri.path}')),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [profileProvider.overrideWith((ref) => defaultProfile(pace: Pace.packed))],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

String _at(GoRouter router) => router.routerDelegate.currentConfiguration.uri.path;

void main() {
  group('Sidebar', () {
    forBothModes('shows every place, the brand and the account', (tester, mode) async {
      await _host(tester, (location) => Sidebar(location: location), mode: mode);
      expect(find.text('TravelGenie'), findsOneWidget);
      for (final place in ShellPlace.values) {
        expect(find.bySemanticsLabel(place.label), findsOneWidget, reason: place.label);
      }
      expect(find.text('Sam Haddad'), findsOneWidget);
      expect(find.text('Packed pace'), findsOneWidget);
      final sidebar = tester.widget<AnimatedContainer>(
        find.descendant(of: find.byType(Sidebar), matching: find.byType(AnimatedContainer)).first,
      );
      final palette = mode == ThemeMode.dark ? AppPalette.dark : AppPalette.light;
      expect((sidebar.decoration! as BoxDecoration).color, palette.bgSidebar);
    });

    testWidgets('the active item follows the location', (tester) async {
      await _host(tester, (location) => Sidebar(location: location), initial: '/plans');
      final items = tester.widgetList<SidebarItem>(find.byType(SidebarItem));
      expect(items.where((i) => i.active).map((i) => i.label), ['My plans']);
    });

    testWidgets('each place navigates to its page', (tester) async {
      final router = await _host(tester, (location) => Sidebar(location: location));
      for (final (label, path) in [
        ('Explore', '/discover'),
        ('My plans', '/plans'),
        ('Saved', '/saved'),
        ('New trip chat', '/'),
      ]) {
        await tester.tap(find.bySemanticsLabel(label));
        await tester.pumpAndSettle();
        expect(_at(router), path, reason: label);
      }
    });

    testWidgets('Search chats opens its dialog', (tester) async {
      await _host(tester, (location) => Sidebar(location: location));
      await tester.tap(find.bySemanticsLabel('Search chats'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchChatsView), findsOneWidget);
    });

    testWidgets('collapses to a rail of icons and opens again', (tester) async {
      final router = await _host(tester, (location) => Sidebar(location: location));
      await tester.tap(find.byTooltip('Close sidebar'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(Sidebar)).width, Sidebar.railWidth);
      expect(find.text('TravelGenie'), findsNothing);

      await tester.tap(find.byTooltip('Explore'));
      await tester.pumpAndSettle();
      expect(_at(router), '/discover');

      await tester.tap(find.byTooltip('Open sidebar'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(Sidebar)).width, Sidebar.width);
    });
  });

  group('AppDrawer', () {
    testWidgets('lists the places with a search field, and closes after a choice', (tester) async {
      final router = await _host(tester, (_) => const SizedBox.shrink(), size: phone);
      final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold))..openDrawer();
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Search chats and plans'), findsOneWidget);
      expect(find.bySemanticsLabel('Search chats'), findsNothing, reason: 'the field replaces the item');
      expect(find.bySemanticsLabel('Explore'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Explore'));
      await tester.pumpAndSettle();
      expect(_at(router), '/discover');
      expect(scaffold.isDrawerOpen, isFalse);
    });
  });

  group('MobileTopBar', () {
    testWidgets('names the place and opens a new chat', (tester) async {
      var menu = 0;
      final router = await _host(
        tester,
        (location) => SizedBox(
          width: 300,
          child: MobileTopBar(location: location, onMenu: () => menu++),
        ),
        size: phone,
        initial: '/plans',
      );
      expect(find.text('My plans'), findsOneWidget);
      await tester.tap(find.byTooltip('Open menu'));
      expect(menu, 1);
      await tester.tap(find.byTooltip('New trip chat'));
      await tester.pumpAndSettle();
      expect(_at(router), '/');
      expect(find.text('TravelGenie'), findsOneWidget);
    });

    test('shows on the top-level places only', () {
      for (final path in ['/', '/saved', '/discover', '/plans', '/profile', '/chat/c1']) {
        expect(MobileTopBar.showsOn(path), isTrue, reason: path);
      }
      for (final path in ['/discover/destination/1', '/plans/p1', '/profile/edit']) {
        expect(MobileTopBar.showsOn(path), isFalse, reason: path);
      }
    });
  });

  group('AccountMenu', () {
    testWidgets('opens Preferences and account', (tester) async {
      final router = await _host(tester, (_) => const SizedBox(width: 272, child: AccountRow()));
      await tester.tap(find.bySemanticsLabel(RegExp('^Account')));
      await tester.pumpAndSettle();
      expect(find.byType(AccountMenuContent), findsOneWidget);
      await tester.tap(find.text('Preferences and account'));
      await tester.pumpAndSettle();
      expect(_at(router), '/profile');
      expect(find.byType(AccountMenuContent), findsNothing);
    });

    testWidgets('Appearance writes the choice; on phones the menu is a sheet', (tester) async {
      await _host(tester, (_) => const SizedBox(width: 272, child: AccountRow()), size: phone);
      await tester.tap(find.bySemanticsLabel(RegExp('^Account')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byType(AccountMenuContent)));
      expect(container.read(appearanceProvider), ThemeMode.dark);
      expect((await SharedPreferences.getInstance()).getString('appearance'), 'dark');
    });

    testWidgets('Sign out signs out', (tester) async {
      final auth = FakeAuthRepository(user: confirmedUser);
      SharedPreferences.setMockInitialValues({});
      tester.view
        ..physicalSize = desktop
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: signedIn(auth: auth),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: SizedBox(width: 272, child: AccountRow())),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(RegExp('^Account')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(auth.calls, contains('signOut'));
    });
  });
}
