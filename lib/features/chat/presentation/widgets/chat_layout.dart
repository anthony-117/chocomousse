import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/side_panel/application/side_panel_controller.dart';
import 'package:chocomousse/features/side_panel/presentation/side_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The home or a chat, with its side panel beside it from [kWideLayoutBreakpoint] when the panel is open. On phones
/// the panel is a sheet ([showSidePanelSheet]), so this shows [child] alone.
class ChatLayout extends ConsumerWidget {
  const ChatLayout({required this.chatKey, required this.child, super.key});

  final String chatKey;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= kWideLayoutBreakpoint;
    final open = ref.watch(sidePanelProvider(chatKey).select((s) => s.open));
    if (!wide || !open) return child;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: child),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: context.palette.borderDefault)),
          ),
          child: SizedBox(
            width: kSidePanelWidth,
            child: SidePanel(chatKey: chatKey),
          ),
        ),
      ],
    );
  }
}

/// Keeps a chat's column readable on wide screens.
class ChatColumn extends StatelessWidget {
  const ChatColumn({required this.child, super.key});

  static const maxWidth = 760.0;

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
