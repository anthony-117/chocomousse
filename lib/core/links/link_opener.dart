import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a link outside the app. Returns false when it could not be opened.
typedef LinkOpener = Future<bool> Function(String url);

/// Tests replace this, so they never leave the app.
final linkOpenerProvider = Provider<LinkOpener>(
  (ref) => (url) async {
    try {
      return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  },
);
