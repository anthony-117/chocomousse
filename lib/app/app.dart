import 'dart:async';

import 'package:chocomousse/app/router.dart';
import 'package:chocomousse/app/theme/app_theme.dart';
import 'package:chocomousse/features/account/application/session.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TravelGenieApp extends ConsumerStatefulWidget {
  const TravelGenieApp({super.key});

  @override
  ConsumerState<TravelGenieApp> createState() => _TravelGenieAppState();
}

class _TravelGenieAppState extends ConsumerState<TravelGenieApp> {
  @override
  void initState() {
    super.initState();
    // Each confirmed traveller's trips start from their profile (spec FR-005).
    ref.listenManual(authUserProvider.select((u) => u.value?.emailConfirmed ?? false ? u.value?.id : null), (_, id) {
      if (id != null) unawaited(ref.read(profileSeederProvider).seed());
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TravelGenie',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
