import 'package:chocomousse/app/theme/palette.dart';
import 'package:chocomousse/app/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The message field with its send button (Input in Figma 09/W6). Enter sends; the field stops at 1,000 characters.
class ChatInput extends StatefulWidget {
  const ChatInput({required this.enabled, required this.onSend, super.key});

  /// The API's limit for one message.
  static const maxLength = 1000;

  final bool enabled;
  final ValueChanged<String> onSend;

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSend => widget.enabled && _controller.text.trim().isNotEmpty;

  void _send() {
    if (!_canSend) return;
    widget.onSend(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: AppSpacing.xl, right: AppSpacing.sm),
      decoration: BoxDecoration(color: context.palette.bgApp, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: widget.enabled,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              inputFormatters: [LengthLimitingTextInputFormatter(ChatInput.maxLength)],
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                hintText: 'Ask anything about your trip…',
                hintMaxLines: 1,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm - 2),
            child: IconButton.filled(
              tooltip: 'Send',
              onPressed: _canSend ? _send : null,
              icon: const Icon(Icons.send_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
