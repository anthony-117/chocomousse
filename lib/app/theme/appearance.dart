import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Appearance choice (System, Light, Dark), kept on the device only (spec 008 FR-008). It isn't part of the
/// profile, so each device keeps its own.
class AppearanceController extends Notifier<ThemeMode> {
  /// [initial] is the value `main` read before the first frame, so the app doesn't flash the other mode. Without it,
  /// the stored value is read after build.
  AppearanceController([this.initial]);

  final ThemeMode? initial;

  static const key = 'appearance';

  bool _chosen = false;

  @override
  ThemeMode build() {
    final start = initial;
    if (start != null) return start;
    unawaited(
      read().then((stored) {
        // A choice made while reading wins over the stored value.
        if (ref.mounted && !_chosen) state = stored;
      }),
    );
    return ThemeMode.system;
  }

  /// The stored choice; missing, unknown or unreadable is System.
  static Future<ThemeMode> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return parse(prefs.getString(key));
    } on Object {
      return ThemeMode.system;
    }
  }

  static ThemeMode parse(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  /// Shows [mode] at once and stores it. If storing fails, the choice still holds until the app restarts.
  Future<void> set(ThemeMode mode) async {
    _chosen = true;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, mode.name);
    } on Object {
      // Kept in memory only.
    }
  }
}

final appearanceProvider = NotifierProvider<AppearanceController, ThemeMode>(AppearanceController.new);
