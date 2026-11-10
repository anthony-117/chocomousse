import 'package:chocomousse/app/theme/app_icons.dart';
import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/side_panel/application/side_panel_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The side panel's width beside the chat on wide screens (research R-6, Figma "Side panel", 520 px).
const kSidePanelWidth = 520.0;

/// Below this width, an open panel collapses the sidebar to its rail so the chat keeps at least 360 px.
const kSidebarCollapseWidth = 1200.0;

extension PanelPaneLook on PanelPane {
  String get label => switch (this) {
    PanelPane.trip => 'Trip',
    PanelPane.plan => 'Plan',
    PanelPane.details => 'Details',
    PanelPane.map => 'Map',
    PanelPane.saved => 'Saved',
  };

  AppIcons get icon => switch (this) {
    PanelPane.trip => AppIcons.compass,
    PanelPane.plan => AppIcons.calendar,
    PanelPane.details => AppIcons.ticket,
    PanelPane.map => AppIcons.map,
    PanelPane.saved => AppIcons.bookmark,
  };
}

/// Builds the content of one pane. The stories fill the panes in; until then each shows a placeholder.
typedef PaneBuilder = Widget Function(BuildContext context, String chatKey);

/// The panes' content, by pane. Stories register theirs here (spec 008 US2, US3, US6).
final Map<PanelPane, PaneBuilder> panelPanes = {};

/// The side panel of a chat (or of the home, key `home`): the icon bar and the active pane. The same widget sits
/// beside the chat on wide screens and in a sheet on phones.
class SidePanel extends ConsumerWidget {
  const SidePanel({required this.chatKey, this.onClose, super.key});

  final String chatKey;

  /// Called after Close, e.g. to pop the phone sheet.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sidePanelProvider(chatKey));
    final palette = context.palette;
    return ColoredBox(
      color: palette.bgSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelIconBar(
            active: state.pane,
            onSelect: ref.read(sidePanelProvider(chatKey).notifier).openPane,
            onClose: () {
              ref.read(sidePanelProvider(chatKey).notifier).close();
              onClose?.call();
            },
          ),
          Expanded(
            child: IndexedStack(
              index: state.pane.index,
              sizing: StackFit.expand,
              children: [
                for (final pane in PanelPane.values) (panelPanes[pane] ?? _placeholder(pane))(context, chatKey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static PaneBuilder _placeholder(PanelPane pane) =>
      (context, _) => Center(
        child: Text(pane.label, style: AppText.body.copyWith(color: context.palette.textSecondary)),
      );
}

/// The panel's tabs (Trip, Plan, Details, Map, Saved) and Close. The active tab shows its name.
class PanelIconBar extends StatelessWidget {
  const PanelIconBar({required this.active, required this.onSelect, required this.onClose, super.key});

  final PanelPane active;
  final ValueChanged<PanelPane> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 53,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.borderDefault)),
      ),
      child: Row(
        children: [
          for (final pane in PanelPane.values) ...[
            _Tab(pane: pane, active: pane == active, onTap: () => onSelect(pane)),
            const SizedBox(width: AppSpacing.xs),
          ],
          const Spacer(),
          IconButton(
            tooltip: 'Close panel',
            onPressed: onClose,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
            icon: AppIcon(AppIcons.x, size: 18, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.pane, required this.active, required this.onTap});

  final PanelPane pane;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = active ? palette.brandPrimary : palette.textSecondary;
    return Semantics(
      button: true,
      selected: active,
      label: pane.label,
      excludeSemantics: true,
      child: Tooltip(
        message: pane.label,
        child: Material(
          color: active ? palette.brandPrimarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: onTap,
            child: SizedBox(
              height: 32,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: active ? 12 : 9),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(pane.icon, size: 18, color: color),
                    if (active) ...[
                      const SizedBox(width: 6),
                      Text(pane.label, style: AppText.smallStrong.copyWith(color: color)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the panel in a sheet on phones (research R-6): it opens at 90 % of the height and can be dragged to half.
Future<void> showSidePanelSheet(BuildContext context, String chatKey) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (sheetContext) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.9,
    minChildSize: 0.5,
    builder: (_, _) => SidePanel(chatKey: chatKey, onClose: () => Navigator.of(sheetContext).pop()),
  ),
);
