import 'package:chocomousse/app/app.dart';
import 'package:chocomousse/features/assistant/data/assistant_repository.dart';
import 'package:chocomousse/features/assistant/presentation/widgets/action_card.dart';
import 'package:chocomousse/features/destination/data/destination_repository.dart';
import 'package:chocomousse/features/hotels/data/hotel_repository.dart';
import 'package:chocomousse/features/system/data/system_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../account/fakes.dart';
import '../assistant/fakes.dart';
import '../destination/fakes.dart';
import '../helpers.dart';
import '../hotels/fakes.dart';

void main() {
  testWidgets('Rome overview → Ask the assistant → answer with a card → hotels for the card’s dates', (tester) async {
    usePhoneSize(tester, height: 2400);
    final assistant = FakeAssistantRepository()
      ..answerWith(
        reply(
          'Hotel Artemide: 612 USD for the stay.',
          cards: [cardJson(from: '2027-05-03', to: '2027-05-07', adults: 3, subtitle: '3 – 7 May · 3 adults')],
        ),
      );
    final hotels = FakeHotelRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...signedIn(),
          destinationRepositoryProvider.overrideWithValue(FakeDestinationRepository()),
          assistantRepositoryProvider.overrideWithValue(assistant),
          hotelRepositoryProvider.overrideWithValue(hotels),
          pingProvider.overrideWith(
            (ref) async =>
                PingInfo(name: 'pamplemousse', version: '1.0.0', environment: 'Test', utcNow: DateTime.utc(2026)),
          ),
        ],
        child: const TravelGenieApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rome'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ask the assistant'));
    await tester.tap(find.text('Ask the assistant'));
    await tester.pumpAndSettle();

    expect(find.textContaining('About Rome · '), findsOneWidget);
    await tester.ensureVisible(find.text('Cheaper hotels'));
    await tester.tap(find.text('Cheaper hotels'));
    await tester.pumpAndSettle();

    final sent = assistant.requests.single;
    expect(sent.messages.single.text, 'Cheaper hotels');
    expect(sent.context.destinationId, '3169070');
    expect(find.text('Hotel Artemide: 612 USD for the stay.'), findsOneWidget);
    expect(hotels.queries, isEmpty);

    await tester.tap(find.byType(ActionCard));
    await tester.pumpAndSettle();

    final query = hotels.queries.single;
    expect(
      (query.destinationId, query.from, query.to, query.adults),
      ('3169070', DateTime(2027, 5, 3), DateTime(2027, 5, 7), 3),
    );
    expect(find.text('Hotels in Rome'), findsOneWidget);

    // Back from hotels lands on Rome's overview; the chat is still there in the Assistant tab.
    await tester.tap(find.byTooltip('Back').first);
    await tester.pumpAndSettle();
    expect(find.text('Ask the assistant'), findsOneWidget);
    await tester.tap(find.byTooltip('Assistant'));
    await tester.pumpAndSettle();
    expect(find.text('Hotel Artemide: 612 USD for the stay.'), findsOneWidget);
  });
}
