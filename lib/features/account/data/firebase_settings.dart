import 'package:chocomousse/env.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase's app settings for this platform, from `app.env` (ADR 0020).
///
/// [missing] names the first blank setting; [options] is null until every one is set.
class FirebaseSettings {
  FirebaseSettings._(this.options, this.missing);

  factory FirebaseSettings.fromEnv({bool isWeb = kIsWeb}) {
    final values = <String, String>{
      'FIREBASE_PROJECT_ID': Env.firebaseProjectId,
      'FIREBASE_MESSAGING_SENDER_ID': Env.firebaseMessagingSenderId,
      if (isWeb) ...{
        'FIREBASE_WEB_APP_ID': Env.firebaseWebAppId,
        'FIREBASE_WEB_API_KEY': Env.firebaseWebApiKey,
        'FIREBASE_AUTH_DOMAIN': Env.firebaseAuthDomain,
      } else ...{
        'FIREBASE_ANDROID_APP_ID': Env.firebaseAndroidAppId,
        'FIREBASE_ANDROID_API_KEY': Env.firebaseAndroidApiKey,
      },
    };
    final missing = values.entries.where((e) => e.value.trim().isEmpty).map((e) => e.key).firstOrNull;
    if (missing != null) return FirebaseSettings._(null, missing);

    return FirebaseSettings._(
      FirebaseOptions(
        apiKey: isWeb ? Env.firebaseWebApiKey : Env.firebaseAndroidApiKey,
        appId: isWeb ? Env.firebaseWebAppId : Env.firebaseAndroidAppId,
        messagingSenderId: Env.firebaseMessagingSenderId,
        projectId: Env.firebaseProjectId,
        authDomain: isWeb ? Env.firebaseAuthDomain : null,
      ),
      null,
    );
  }

  final FirebaseOptions? options;
  final String? missing;
}
