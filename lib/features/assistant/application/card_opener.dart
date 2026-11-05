import 'package:chocomousse/features/assistant/data/assistant_models.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/flights/application/flight_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Puts a card's trip into the shared settings, so its screen opens with the same dates, adults and departure city
/// the assistant searched with (spec 003-assistant-screen, FR-004). The caller then opens [AssistantCard.route].
class CardOpener {
  const CardOpener(this._ref);

  final Ref _ref;

  Future<void> apply(AssistantCard card) async {
    final trip = _ref.read(tripSettingsProvider.notifier);
    final (from, to) = (card.from, card.to);
    if (from != null && to != null) trip.setDates(from, to);
    final adults = card.adults;
    if (adults != null) trip.setAdults(adults);

    final originId = card.originId;
    if (originId != null && _ref.read(departureCityProvider)?.id != originId) {
      try {
        final origin = await _ref.read(destinationRepositoryProvider).destination(originId);
        _ref.read(departureCityProvider.notifier).choose(origin);
      } on Object {
        // The flights screen then asks for the departure city itself; the card still opens.
      }
    }
  }
}

final cardOpenerProvider = Provider<CardOpener>(CardOpener.new);
