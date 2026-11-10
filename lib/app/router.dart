import 'package:chocomousse/app/auth_guard.dart';
import 'package:chocomousse/features/account/application/session.dart';
import 'package:chocomousse/features/account/data/auth_repository.dart';
import 'package:chocomousse/features/account/presentation/auth_screens.dart';
import 'package:chocomousse/features/account/presentation/edit_profile_screen.dart';
import 'package:chocomousse/features/account/presentation/profile_screen.dart';
import 'package:chocomousse/features/assistant/presentation/assistant_screen.dart';
import 'package:chocomousse/features/cars/presentation/car_details_screen.dart';
import 'package:chocomousse/features/cars/presentation/cars_screen.dart';
import 'package:chocomousse/features/destination/presentation/overview_screen.dart';
import 'package:chocomousse/features/destination/presentation/place_details_screen.dart';
import 'package:chocomousse/features/destination/presentation/places_screen.dart';
import 'package:chocomousse/features/destination/presentation/search_screen.dart';
import 'package:chocomousse/features/discover/presentation/discover_screen.dart';
import 'package:chocomousse/features/flights/presentation/flights_screen.dart';
import 'package:chocomousse/features/hotels/presentation/hotel_details_screen.dart';
import 'package:chocomousse/features/hotels/presentation/hotels_screen.dart';
import 'package:chocomousse/features/itinerary/data/plan_models.dart';
import 'package:chocomousse/features/itinerary/presentation/build_plan_screen.dart';
import 'package:chocomousse/features/itinerary/presentation/change_offer_screen.dart';
import 'package:chocomousse/features/itinerary/presentation/itinerary_screen.dart';
import 'package:chocomousse/features/itinerary/presentation/my_plans_screen.dart';
import 'package:chocomousse/features/ranking/data/ranking_models.dart';
import 'package:chocomousse/features/ranking/presentation/best_for_you_screen.dart';
import 'package:chocomousse/features/ranking/presentation/plan_trip_screen.dart';
import 'package:chocomousse/features/shell/app_shell.dart';
import 'package:chocomousse/features/shell/chat_placeholder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The shell's top-level places (spec 008 research R-5). Explore, My plans and the profile keep their v0.2 routes.
abstract final class AppPaths {
  static const home = '/';
  static const saved = '/saved';
  static const explore = '/discover';
  static const plans = '/plans';
  static const profile = '/profile';

  static String chat(String id) => '/chat/$id';
}

final routerProvider = Provider<GoRouter>((ref) {
  // The router asks again where to go whenever the traveller signs in or out (spec FR-003).
  final session = ValueNotifier<AsyncValue<AuthUser?>>(ref.read(authUserProvider));
  ref
    ..listen(authUserProvider, (_, next) => session.value = next)
    ..onDispose(session.dispose);
  return GoRouter(
    initialLocation: AppPaths.home,
    refreshListenable: session,
    redirect: (context, state) => authRedirect(session.value, state.uri),
    routes: [
      GoRoute(path: AuthPaths.starting, builder: (context, state) => const StartingScreen()),
      GoRoute(path: AuthPaths.welcome, builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: AuthPaths.signIn, builder: (context, state) => const SignInScreen()),
      GoRoute(path: AuthPaths.signUp, builder: (context, state) => const SignUpScreen()),
      GoRoute(path: AuthPaths.forgotPassword, builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: AuthPaths.checkEmail, builder: (context, state) => const CheckEmailScreen()),
      // The v0.2 Assistant tab's address now opens the home.
      GoRoute(path: '/assistant', redirect: (context, state) => AppPaths.home),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          // The v0.2 assistant stays the home until the v1 home is built (spec 008 T051).
          GoRoute(path: AppPaths.home, builder: (context, state) => const AssistantScreen()),
          GoRoute(
            path: '/chat/:chatId',
            builder: (context, state) => ChatPlaceholder(chatId: state.pathParameters['chatId']!),
          ),
          GoRoute(path: AppPaths.saved, builder: (context, state) => const AssistantScreen()),
          GoRoute(
            path: AppPaths.explore,
            builder: (context, state) => const DiscoverScreen(),
            routes: [
              GoRoute(path: 'search', builder: (context, state) => const SearchScreen()),
              GoRoute(
                path: 'destination/:id',
                builder: (context, state) => OverviewScreen(id: state.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'places',
                    builder: (context, state) => PlacesScreen(
                      id: state.pathParameters['id']!,
                      initialCategory: state.uri.queryParameters['category'],
                    ),
                  ),
                  GoRoute(
                    path: 'flights',
                    builder: (context, state) => FlightsScreen(id: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'hotels',
                    builder: (context, state) => HotelsScreen(id: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: ':hotelId',
                        builder: (context, state) => HotelDetailsScreen(hotelId: state.pathParameters['hotelId']!),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'cars',
                    builder: (context, state) => CarsScreen(id: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: ':carId',
                        // A car is shown from the search it was tapped in; opened without one (a reload or
                        // a shared link), it goes to the list instead (spec FR-010).
                        redirect: (context, state) => state.extra is CarDetailsArgs
                            ? null
                            : '/discover/destination/${state.pathParameters['id']}/cars',
                        builder: (context, state) => CarDetailsScreen(args: state.extra! as CarDetailsArgs),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'plan',
                    builder: (context, state) {
                      final edit = state.uri.queryParameters['edit'];
                      return PlanTripScreen(
                        id: state.pathParameters['id']!,
                        returnTo: edit == null ? null : RankedKind.parse(edit),
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'best',
                        builder: (context, state) => BestForYouScreen(
                          id: state.pathParameters['id']!,
                          tab: RankedKind.parse(state.uri.queryParameters['tab']),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: 'place/:placeId',
                builder: (context, state) => PlaceDetailsScreen(placeId: state.pathParameters['placeId']!),
              ),
            ],
          ),
          GoRoute(
            path: AppPaths.plans,
            builder: (context, state) => const MyPlansScreen(),
            routes: [
              GoRoute(
                path: 'new',
                // A build starts from Best for you or the overview; opened without one (a reload), it goes to
                // My plans instead of building again.
                redirect: (context, state) => state.extra is BuildPlanRequest ? null : AppPaths.plans,
                builder: (context, state) => BuildPlanScreen(request: state.extra! as BuildPlanRequest),
              ),
              GoRoute(
                path: ':planId',
                builder: (context, state) => ItineraryScreen(
                  id: state.pathParameters['planId']!,
                  day: int.tryParse(state.uri.queryParameters['day'] ?? ''),
                ),
                routes: [
                  GoRoute(
                    path: 'change/:kind',
                    redirect: (context, state) => OfferKind.parse(state.pathParameters['kind']) == null
                        ? '/plans/${state.pathParameters['planId']}'
                        : null,
                    builder: (context, state) => ChangeOfferScreen(
                      planId: state.pathParameters['planId']!,
                      kind: OfferKind.parse(state.pathParameters['kind'])!,
                    ),
                  ),
                  // Place details inside the Plans tab, so Back returns to the day (plan decision 6).
                  GoRoute(
                    path: 'place/:placeId',
                    builder: (context, state) => PlaceDetailsScreen(placeId: state.pathParameters['placeId']!),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: AppPaths.profile,
            builder: (context, state) => const ProfileScreen(),
            routes: [GoRoute(path: 'edit', builder: (context, state) => const EditProfileScreen())],
          ),
        ],
      ),
    ],
  );
});
