import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:flutter/material.dart';

/// Stands in for the chat screen at `/chat/{id}` until it is built (spec 008 T052).
class ChatPlaceholder extends StatelessWidget {
  const ChatPlaceholder({required this.chatId, super.key});

  final String chatId;

  @override
  Widget build(BuildContext context) => Center(
    child: Text('Chat $chatId', style: AppText.body.copyWith(color: context.palette.textSecondary)),
  );
}
