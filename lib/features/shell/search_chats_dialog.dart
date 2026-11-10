import 'dart:async';

import 'package:chocomousse/app/theme/app_text.dart';
import 'package:chocomousse/app/theme/palette.dart';
import 'package:flutter/material.dart';

/// Opens Search chats. The search itself comes with Recents (spec 008 T070); until then the dialog says so.
void showSearchChats(BuildContext context) {
  unawaited(
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Search chats'),
        content: Text(
          'Searching your chats and plans is coming soon.',
          style: AppText.body.copyWith(color: dialogContext.palette.textSecondary),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close'))],
      ),
    ),
  );
}
