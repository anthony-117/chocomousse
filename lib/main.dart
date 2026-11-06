import 'package:chocomousse/app/app.dart';
import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/env.dart';
import 'package:chocomousse/features/account/application/session.dart';
import 'package:chocomousse/features/account/data/auth_repository.dart';
import 'package:chocomousse/features/account/data/firebase_settings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();

  // Without every Firebase setting the app still runs; Welcome says sign-in isn't set up (ADR 0020).
  final settings = FirebaseSettings.fromEnv();
  final AuthRepository auth;
  if (settings.options case final options?) {
    await Firebase.initializeApp(options: options);
    auth = FirebaseAuthRepository(FirebaseAuth.instance);
  } else {
    auth = NotConfiguredAuthRepository(settings.missing!);
  }

  runApp(ProviderScope(retry: noRetry, overrides: accountOverrides(auth), child: const TravelGenieApp()));
}
