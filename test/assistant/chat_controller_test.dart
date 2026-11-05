import 'dart:async';

import 'package:chocomousse/features/assistant/application/card_opener.dart';
import 'package:chocomousse/features/assistant/application/chat_controller.dart';
import 'package:chocomousse/features/assistant/data/assistant_models.dart';
import 'package:chocomousse/features/assistant/data/assistant_repository.dart';
import 'package:chocomousse/features/destination/application/destination_providers.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/flights/application/flight_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../destination/fakes.dart';
import 'fakes.dart';

void main() {
  late FakeAssistantRepository api;
  late ProviderContainer container;

  ChatController chat() => container.read(chatControllerProvider.notifier);
  ChatState state() => container.read(chatControllerProvider);

  setUp(() {
    api = FakeAssistantRepository();
    container = ProviderContainer(
      overrides: [
        assistantRepositoryProvider.overrideWithValue(api),
        destinationRepositoryProvider.overrideWithValue(FakeDestinationRepository()),
      ],
    );
    addTearDown(container.dispose);
  });

  test('sending adds the message at once, then the answer with its cards', () async {
    final answer = Completer<AssistantReply>();
    api.pending = answer;

    final sending = chat().send('  Hotels?  ');
    expect(state().messages.single.text, 'Hotels?');
    expect(state().sending, isTrue);

    answer.complete(reply('Two hotels.', cards: [cardJson()]));
    await sending;

    expect(state().sending, isFalse);
    final [question, response] = state().messages;
    expect((question.role, response.role, response.text), (ChatRole.traveller, ChatRole.assistant, 'Two hotels.'));
    expect(response.cards.single.title, 'Hotels in Rome');
  });

  test('sends the shared trip, the chat city and the departure city as context', () async {
    container.read(tripSettingsProvider.notifier)
      ..setPassport('FR')
      ..setCurrency('EUR')
      ..setAdults(3)
      ..setDates(DateTime(2027, 4, 10), DateTime(2027, 4, 15));
    container.read(departureCityProvider.notifier).choose(rome);
    chat().startFor((id: '3169070', name: 'Rome'));

    await chat().send('Flights?');

    final context = api.requests.single.context.toJson();
    expect(context, {
      'destinationId': '3169070',
      'from': '2027-04-10',
      'to': '2027-04-15',
      'adults': 3,
      'passport': 'FR',
      'currency': 'EUR',
      'originId': rome.id,
    });
  });

  test('blank text and a second message while one is on its way are ignored', () async {
    api.pending = Completer<AssistantReply>();

    await chat().send('   ');
    unawaited(chat().send('First'));
    await chat().send('Second');

    expect(state().messages.map((m) => m.text), ['First']);
    expect(api.requests, hasLength(1));
  });

  test('a failed request marks the message not sent, and Try again resends it', () async {
    api
      ..answerWith(DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError))
      ..answerWith(reply('Back online.'));

    await chat().send('Visa?');
    expect(state().messages.single.notSent, isTrue);
    expect(state().error, 'Cannot reach the TravelGenie server.');
    expect(state().canRetry, isTrue);

    await chat().retry();

    expect(state().messages.map((m) => (m.text, m.notSent)), [('Visa?', false), ('Back online.', false)]);
    expect(state().error, isNull);
    expect(api.requests, hasLength(2));
  });

  test('a new message after a failure leaves the unsent one out of the conversation', () async {
    api
      ..answerWith(DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError))
      ..answerWith(reply('Mild, around 14 °C.'));

    await chat().send('Visa?');
    await chat().send('Weather?');

    expect(api.requests.last.messages.map((m) => m.text), ['Weather?']);
    expect(state().messages.map((m) => (m.text, m.notSent)), [
      ('Visa?', true),
      ('Weather?', false),
      ('Mild, around 14 °C.', false),
    ]);
  });

  test('a warning-only answer can be retried, and is replaced by the new answer', () async {
    api
      ..answerWith(reply('', warnings: ['The assistant is busy right now. Try again in a minute.']))
      ..answerWith(reply('You need a visa.'));

    await chat().send('Visa?');
    expect(state().messages.last.isWarningOnly, isTrue);

    await chat().retry();

    expect(state().messages.map((m) => m.text), ['Visa?', 'You need a visa.']);
    expect(api.requests.last.messages.map((m) => m.text), ['Visa?']);
  });

  test('retry does nothing when the last answer is fine', () async {
    await chat().send('Hi');

    await chat().retry();

    expect(api.requests, hasLength(1));
  });

  test('startFor keeps a chat about the same city and starts over for another; New chat clears everything', () async {
    chat().startFor((id: '3169070', name: 'Rome'));
    await chat().send('Hi');

    chat().startFor((id: '3169070', name: 'Rome'));
    expect(state().messages, hasLength(2));

    chat().startFor((id: '2988507', name: 'Paris'));
    expect(state().messages, isEmpty);
    expect(state().city?.name, 'Paris');

    chat().newChat();
    expect((state().isEmpty, state().city), (true, null));
  });

  test('opening a card puts its dates, adults and departure city into the shared settings', () async {
    final card = AssistantCard.fromJson(
      cardJson(kind: 'flights', from: '2027-05-01', to: '2027-05-06', adults: 4, originId: '2988507'),
    )!;

    await container.read(cardOpenerProvider).apply(card);

    final trip = container.read(tripSettingsProvider);
    expect((trip.from, trip.to, trip.adults), (DateTime(2027, 5), DateTime(2027, 5, 6), 4));
    // The fake API answers every city id with Rome.
    expect(container.read(departureCityProvider)?.name, 'Rome');
  });

  test('a card without dates leaves the shared settings alone', () async {
    final before = container.read(tripSettingsProvider);
    final card = AssistantCard.fromJson(cardJson(kind: 'places', from: null, to: null, adults: null))!;

    await container.read(cardOpenerProvider).apply(card);

    final after = container.read(tripSettingsProvider);
    expect((after.from, after.to, after.adults), (before.from, before.to, before.adults));
  });
}
