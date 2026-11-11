import 'package:chocomousse/app/router.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/shell/app_drawer.dart';
import 'package:chocomousse/features/shell/mobile_top_bar.dart';
import 'package:chocomousse/features/shell/sidebar.dart';
import 'package:chocomousse/features/side_panel/application/side_panel_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Below this width an open side panel collapses the sidebar to its rail, so the chat keeps room (research R-6).
const double kPanelRoomBreakpoint = 1200;

/// The side panel shown at [location]: the home's on `/` and `/saved`, a chat's on `/chat/{id}`; none elsewhere.
String? panelKeyAt(String location) {
  if (location == AppPaths.home || location == AppPaths.saved) return homePanelKey;
  final chat = RegExp(r'^/chat/([^/]+)$').firstMatch(location);
  return chat == null ? null : Uri.decodeComponent(chat.group(1)!);
}

/// The v1 shell (spec 008 US4): the sidebar beside the page on wide screens; on phones, a top bar with the menu that
/// opens the drawer. Pages deeper than the top-level places keep their own back header on phones.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.location, required this.child, super.key});

  /// The current path, for the active item and the top bar's title.
  final String location;
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _scaffold = GlobalKey<ScaffoldState>();

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A choice made from the drawer (the account menu, a search result) closes it.
    if (oldWidget.location != widget.location) _scaffold.currentState?.closeDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= kWideLayoutBreakpoint) {
      final panelKey = panelKeyAt(widget.location);
      final panelOpen = panelKey != null && ref.watch(sidePanelProvider(panelKey).select((s) => s.open));
      return Scaffold(
        backgroundColor: context.palette.bgApp,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Sidebar(location: widget.location, forceRail: panelOpen && width < kPanelRoomBreakpoint),
            Expanded(child: widget.child),
          ],
        ),
      );
    }
    return Scaffold(
      key: _scaffold,
      backgroundColor: context.palette.bgApp,
      drawer: AppDrawer(location: widget.location),
      appBar: MobileTopBar.showsOn(widget.location)
          ? MobileTopBar(location: widget.location, onMenu: () => _scaffold.currentState?.openDrawer())
          : null,
      body: widget.child,
    );
  }
}
