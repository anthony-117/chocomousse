import 'dart:async';

import 'package:chocomousse/app/theme/app_icons.dart';
import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:chocomousse/features/chat/application/chat_trip.dart';
import 'package:chocomousse/features/chat/data/chat_models.dart';
import 'package:chocomousse/features/chat/presentation/trip_sheets.dart';
import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:chocomousse/features/itinerary/presentation/widgets/plan_texts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The most a message can hold (API spec 010).
const int kMaxMessageLength = ChatRequest.maxLength;

/// The notice under the composer (research R-8).
const kAiNotice = "Messages are answered by an AI service and may be used to improve it. Don't share personal details.";

/// "Rome · 10 – 14 Apr · 2 adults", or "Add trip".
String tripChipLabel(ChatTrip trip) {
  final from = trip.from;
  final to = trip.to;
  final parts = [
    ?trip.destinationName,
    if (from != null && to != null) planDates(from, to),
    if (trip.adults case final n?) adults(n),
  ];
  return parts.isEmpty ? 'Add trip' : parts.join(' · ');
}

String _interest(Criterion c) => c == Criterion.culture ? 'Culture' : c.label;

/// The two interests that weigh most, then the pace: "Culture · Food · Balanced", or "Add preferences".
String preferencesChipLabel(ChatTripState state) {
  if (state.preferences.isEmpty) return 'Add preferences';
  const interests = [Criterion.culture, Criterion.food, Criterion.nature, Criterion.nightlife];
  final top = [...interests]
    ..sort((a, b) => (state.preferences[b.name] ?? 0).compareTo(state.preferences[a.name] ?? 0));
  return [...top.take(2).map(_interest), state.pace.label].join(' · ');
}

/// Whether Enter sends (Shift+Enter makes a new line): on the web and the desktop apps, where a keyboard is the norm.
bool get _enterSendsByDefault =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.linux;

/// The message field with its chips (Figma 2302:111): "+", the trip, the preferences and send. No mic.
class Composer extends ConsumerStatefulWidget {
  const Composer({required this.onSend, this.sending = false, this.enterSends, this.autofocus = false, super.key});

  final ValueChanged<String> onSend;

  /// While an answer runs, nothing more can be sent.
  final bool sending;

  /// Null: on the web and desktops.
  final bool? enterSends;

  final bool autofocus;

  @override
  ConsumerState<Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<Composer> {
  final _text = TextEditingController();
  late final _focus = FocusNode(onKeyEvent: _onKey);

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _canSend => !widget.sending && ChatRequest.textError(_text.text) == null;

  void _send() {
    if (!_canSend) return;
    widget.onSend(_text.text.trim());
    _text.clear();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!(widget.enterSends ?? _enterSendsByDefault)) return KeyEventResult.ignored;
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.enter) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;
    _send();
    return KeyEventResult.handled;
  }

  Future<void> _more() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const AppIcon(AppIcons.calendar),
              title: const Text('Trip'),
              onTap: () => Navigator.of(context).pop('trip'),
            ),
            ListTile(
              leading: const AppIcon(AppIcons.sliders),
              title: const Text('Preferences'),
              onTap: () => Navigator.of(context).pop('preferences'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'trip':
        await showTripEditor(context);
      case 'preferences':
        await showPreferencesSheet(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final chips = ref.watch(chatTripProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
          decoration: BoxDecoration(
            color: palette.bgSurface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: palette.borderDefault),
            boxShadow: palette.raisedShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _text,
                focusNode: _focus,
                autofocus: widget.autofocus,
                minLines: 1,
                maxLines: 6,
                keyboardType: TextInputType.multiline,
                inputFormatters: [LengthLimitingTextInputFormatter(kMaxMessageLength)],
                style: AppText.body.copyWith(color: palette.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Ask anything about your trip',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Add trip or preferences',
                    onPressed: () => unawaited(_more()),
                    icon: AppIcon(AppIcons.plus, color: palette.textSecondary),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _Chip(
                            icon: AppIcons.calendar,
                            label: tripChipLabel(chips.trip),
                            onTap: () => unawaited(showTripEditor(context)),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _Chip(
                            icon: AppIcons.sliders,
                            label: preferencesChipLabel(chips),
                            onTap: () => unawaited(showPreferencesSheet(context)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: _canSend ? _send : null,
                    icon: AppIcon(AppIcons.arrowUp, color: palette.brandOnPrimary),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          kAiNotice,
          textAlign: TextAlign.center,
          style: AppText.small.copyWith(color: palette.textTertiary),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.onTap});

  final AppIcons icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: palette.bgSubtle,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.full),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(icon, size: 14, color: palette.textSecondary),
                const SizedBox(width: 6),
                Text(label, style: AppText.smallStrong.copyWith(color: palette.textPrimary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
