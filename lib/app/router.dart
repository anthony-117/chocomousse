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
import 'package:chocomousse/features/plans/presentation/plans_screen.dart';
import 'package:chocomousse/features/profile/presentation/profile_screen.dart';
import 'package:chocomousse/features/ranking/data/ranking_models.dart';
import 'package:chocomousse/features/ranking/presentation/best_for_you_screen.dart';
import 'package:chocomousse/features/ranking/presentation/plan_trip_screen.dart';
import 'package:chocomousse/features/shell/app_shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Top-level destinations, in the order shown by the floating nav and the web header.
enum AppTab {
  discover('/discover', 'Discover'),
  plans('/plans', 'Plans'),
  assistant('/assistant', 'Assistant'),
  profile('/profile', 'Profile');

  AppTab(this.path, this.label);

  final String path;
  final String label;
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppTab.discover.path,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppTab.discover.path,
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
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppTab.plans.path, builder: (context, state) => const PlansScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppTab.assistant.path, builder: (context, state) => const AssistantScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppTab.profile.path, builder: (context, state) => const ProfileScreen())],
          ),
        ],
      ),
    ],
  );
});
