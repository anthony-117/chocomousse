import 'package:chocomousse/features/destination/data/preferences.dart';
import 'package:flutter/foundation.dart';

/// Where the traveller's flights leave from.
@immutable
class HomeCity {
  const HomeCity({required this.id, required this.name, required this.countryCode});

  factory HomeCity.fromJson(Map<String, dynamic> json) =>
      HomeCity(id: json['id']! as String, name: json['name']! as String, countryCode: json['countryCode']! as String);

  final String id;
  final String name;
  final String countryCode;

  @override
  bool operator ==(Object other) => other is HomeCity && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The traveller's travel profile (API spec 009, `GET /api/v1/me`).
@immutable
class Profile {
  const Profile({
    required this.displayName,
    required this.email,
    required this.passport,
    required this.homeCurrency,
    required this.homeCity,
    required this.preferences,
    this.pace = Pace.balanced,
  });

  /// The API's weights are read as levels; one the app never sends reads as Medium.
  factory Profile.fromJson(Map<String, dynamic> json) {
    final weights = json['preferences']! as Map<String, dynamic>;
    var preferences = const Preferences();
    for (final criterion in Criterion.values) {
      final level = Level.ofWeight((weights[criterion.name] as num?)?.toInt() ?? Level.medium.weight);
      preferences = preferences.withLevel(criterion, level ?? Level.medium);
    }
    final city = json['homeCity'] as Map<String, dynamic>?;
    return Profile(
      displayName: json['displayName']! as String,
      email: json['email']! as String,
      passport: json['passport']! as String,
      homeCurrency: json['homeCurrency']! as String,
      homeCity: city == null ? null : HomeCity.fromJson(city),
      preferences: preferences,
      pace: Pace.parse(json['pace'] as String?),
    );
  }

  final String displayName;
  final String email;
  final String passport;
  final String homeCurrency;
  final HomeCity? homeCity;
  final Preferences preferences;
  final Pace pace;

  String get initial => displayName.trim().isEmpty ? '?' : displayName.trim()[0].toUpperCase();
}

/// The Edit profile form (P2), sent whole to `PUT /api/v1/me`.
@immutable
class ProfileForm {
  const ProfileForm({
    required this.displayName,
    required this.passport,
    required this.homeCurrency,
    required this.homeCityId,
    required this.preferences,
    this.pace = Pace.balanced,
  });

  factory ProfileForm.of(Profile p) => ProfileForm(
    displayName: p.displayName,
    passport: p.passport,
    homeCurrency: p.homeCurrency,
    homeCityId: p.homeCity?.id,
    preferences: p.preferences,
    pace: p.pace,
  );

  final String displayName;
  final String passport;
  final String homeCurrency;
  final String? homeCityId;
  final Preferences preferences;
  final Pace pace;

  Map<String, Object?> toJson() => {
    'displayName': displayName.trim(),
    'passport': passport,
    'homeCurrency': homeCurrency,
    'homeCityId': homeCityId,
    'preferences': {for (final c in Criterion.values) c.name: preferences.of(c).weight},
    'pace': pace.name,
  };
}

/// The API refused a field; [errors] maps each field to its message (`passport`, `displayName`, `budget`, …).
class ProfileFieldErrors implements Exception {
  const ProfileFieldErrors(this.errors);

  final Map<String, String> errors;

  @override
  String toString() => 'ProfileFieldErrors(${errors.keys.join(', ')})';
}
