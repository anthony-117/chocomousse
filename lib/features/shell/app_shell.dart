import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/shell/app_drawer.dart';
import 'package:chocomousse/features/shell/mobile_top_bar.dart';
import 'package:chocomousse/features/shell/sidebar.dart';
import 'package:flutter/material.dart';

/// The v1 shell (spec 008 US4): the sidebar beside the page on wide screens; on phones, a top bar with the menu that
/// opens the drawer. Pages deeper than the top-level places keep their own back header on phones.
class AppShell extends StatefulWidget {
  const AppShell({required this.location, required this.child, super.key});

  /// The current path, for the active item and the top bar's title.
  final String location;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffold = GlobalKey<ScaffoldState>();

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A choice made from the drawer (the account menu, a search result) closes it.
    if (oldWidget.location != widget.location) _scaffold.currentState?.closeDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    if (wide) {
      return Scaffold(
        backgroundColor: context.palette.bgApp,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Sidebar(location: widget.location),
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
