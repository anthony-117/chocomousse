import 'package:chocomousse/app/app.dart';
import 'package:chocomousse/core/network/api_client.dart';
import 'package:chocomousse/env.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();
  runApp(const ProviderScope(retry: noRetry, child: TravelGenieApp()));
}
