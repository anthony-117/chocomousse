import 'package:chocomousse/app/router.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/shell/floating_nav.dart';
import 'package:chocomousse/features/shell/web_header.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Hosts the four tabs: floating nav on phones (design 01–13), web header on wide screens (W1–W9).
class AppShell extends StatelessWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  void _goTo(AppTab tab) {
    // Tapping the current tab again returns to that tab's first page.
    shell.goBranch(tab.index, initialLocation: tab.index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final current = AppTab.values[shell.currentIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= kWideLayoutBreakpoint) {
          return Scaffold(
            body: Column(
              children: [
                WebHeader(current: current, onSelect: _goTo),
                Expanded(child: shell),
              ],
            ),
          );
        }

        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(child: shell),
              Positioned(
                left: AppSpacing.xl,
                right: AppSpacing.xl,
                bottom: AppSpacing.xl,
                child: SafeArea(
                  top: false,
                  child: FloatingNav(current: current, onSelect: _goTo),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
