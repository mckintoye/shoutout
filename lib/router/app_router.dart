import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_screen.dart';
import '../features/events/create_event_screen.dart';
import '../features/events/event_detail_screen.dart';
import '../features/events/events_home_screen.dart';
import '../features/gallery/upload_playback_screen.dart' show UploadPlaybackScreen;
import '../features/home/home_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/settings_screen.dart';
//import '../features/uploads/preview_screen.dart';
import '../features/gallery/record_screen.dart';
import '../features/gallery/upload_success_screen.dart';
import '../features/gallery/gallery_home_screen.dart';
import '../features/profile/settings_screen.dart';

/// ✅ Keep AppRoutes compatible with your existing codebase.
/// - Some fields are PATHS (used by context.go)
/// - Some fields are NAMES (used by context.goNamed / pushNamed)
class AppRoutes {
  // ---- Paths ----
  static const login = '/login';

  static const app = '/app';

  static const homePath = '/app/home';
  static const eventsPath = '/app/events';
  static const uploadsPath = '/app/uploads';
  static const profilePath = '/app/profile';
  static const settingsPath = '/app/profile/settings';

  // ---- Route NAMES (used by goNamed/pushNamed) ----
  static const home = 'home';
  static const events = 'events';
  static const uploads = 'uploads';
  static const profile = 'profile';
  static const settings = 'settings';
  static const createEvent = 'createEvent';
  static const eventDetail = 'eventDetail';
  static const gallery = 'gallery';

  // Capture flow
  static const record = 'record';
  static const preview = 'preview';
  static const success = 'success';

  static const playback  = 'playback';
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

// Navigators
final _rootKey = GlobalKey<NavigatorState>();
final _homeKey = GlobalKey<NavigatorState>();
final _eventsKey = GlobalKey<NavigatorState>();
final _uploadsKey = GlobalKey<NavigatorState>();
final _profileKey = GlobalKey<NavigatorState>();

class AppRouter {
  static GoRouter create() {
    final auth = FirebaseAuth.instance;

    return GoRouter(
      navigatorKey: _rootKey,
      initialLocation: AppRoutes.login,
      refreshListenable: GoRouterRefreshStream(auth.authStateChanges()),
      redirect: (context, state) {
        final loggedIn = auth.currentUser != null;
        final loc = state.matchedLocation;
        final goingToLogin = loc == AppRoutes.login;

        if (!loggedIn) {
          if (goingToLogin) return null;
          final from = Uri.encodeComponent(state.uri.toString());
          return '${AppRoutes.login}?from=$from';
        }

        if (loggedIn && goingToLogin) {
          final from = state.uri.queryParameters['from'];
          if (from != null && from.isNotEmpty) {
            return Uri.decodeComponent(from);
          }
          return AppRoutes.homePath;
        }

        return null;
      },
      routes: [
        // --------------------------
        // AUTH (no bottom nav)
        // --------------------------
        GoRoute(
          path: '/playback',
          name: AppRoutes.playback,
          parentNavigatorKey: _rootKey,
          builder: (context, state) {
            final extra = state.extra;
            if (extra is! Map<String, dynamic>) {
              return const _RouteErrorScreen(message: 'Missing playback payload.');
            }
            final title = (extra['title'] as String?) ?? 'Video message';
            final url = (extra['videoUrl'] as String?) ?? '';
            return UploadPlaybackScreen(title: title, videoUrl: url);
          },
        ),

        GoRoute(
          path: '/uploads',
          redirect: (context, state) => '/gallery',
        ),

        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),







        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) {
            final from = state.uri.queryParameters['from'];
            return AuthScreen(
              redirectTo: (from != null && from.isNotEmpty)
                  ? Uri.decodeComponent(from)
                  : AppRoutes.homePath,
            );
          },
        ),

        // --------------------------
        // APP SHELL (bottom nav)
        // --------------------------
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return _ShellScaffold(navigationShell: navigationShell);
          },
          branches: [
            // HOME
            StatefulShellBranch(
              navigatorKey: _homeKey,
              routes: [
                GoRoute(
                  path: AppRoutes.homePath,
                  name: AppRoutes.home,
                  builder: (context, state) => const HomeScreen(),
                ),
              ],
            ),

            // EVENTS
            StatefulShellBranch(
              navigatorKey: _eventsKey,
              routes: [
                GoRoute(
                  path: AppRoutes.eventsPath,
                  name: AppRoutes.events,
                  builder: (context, state) => const EventsListScreen(),
                  routes: [
                    GoRoute(
                      path: 'create',
                      name: AppRoutes.createEvent,
                      builder: (context, state) => const CreateEventScreen(),
                    ),
                    GoRoute(
                      path: ':eventId',
                      name: AppRoutes.eventDetail,
                      builder: (context, state) {
                        final id = state.pathParameters['eventId']!;
                        return EventDetailScreen(eventId: id);
                      },
                      routes: [
                        // In-shell page (keeps bottom nav)
                        GoRoute(
                          path: 'gallery',
                          name: AppRoutes.gallery,
                          redirect: (context, state) {
                            final id = state.pathParameters['eventId']!;
                            // send user to the Gallery tab and optionally filter by event
                            return '${AppRoutes.uploadsPath}?eventId=$id';
                          },
                        ),

                        // ✅ FULLSCREEN capture flow (no bottom nav)
                        GoRoute(
                          path: 'record',
                          name: AppRoutes.record,
                          parentNavigatorKey: _rootKey,
                          builder: (context, state) {
                            final id = state.pathParameters['eventId']!;
                            return RecordScreen(eventId: id);
                          },
                        ),
                        /*
                        GoRoute(
                          path: 'preview',
                          name: AppRoutes.preview,
                          parentNavigatorKey: _rootKey,
                          builder: (context, state) {
                            final id = state.pathParameters['eventId']!;
                            final extra = state.extra;
                            if (extra is! Map<String, dynamic>) {
                              return const _RouteErrorScreen(
                                message: 'Missing preview payload (state.extra).',
                              );
                            }
                            return PreviewScreen(eventId: id, payload: extra);
                          },
                        ),
                        */
                        GoRoute(
                          path: 'success',
                          name: AppRoutes.success,
                          parentNavigatorKey: _rootKey,
                          builder: (context, state) {
                            final id = state.pathParameters['eventId']!;
                            return UploadSuccessScreen(eventId: id);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            // UPLOADS TAB
            StatefulShellBranch(
              navigatorKey: _uploadsKey,
              routes: [
                GoRoute(
                  path: AppRoutes.uploadsPath,
                  name: AppRoutes.uploads,
                  builder: (context, state) => const GalleryTab(),
                ),
              ],
            ),

            // PROFILE TAB
            StatefulShellBranch(
              navigatorKey: _profileKey,
              routes: [
                GoRoute(
                  path: AppRoutes.profilePath,
                  name: AppRoutes.profile,
                  builder: (context, state) => const ProfileScreen(),
                  routes: [
                    GoRoute(
                      path: 'settings',
                      name: AppRoutes.settings,
                      builder: (context, state) => const SettingsScreen(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),


        // --------------------------
        // LEGACY PATHS (redirect only)
        // IMPORTANT: do NOT assign names here (prevents duplicate-name crash)
        // --------------------------
        GoRoute(
          path: '/create-event',
          redirect: (_, __) => '${AppRoutes.eventsPath}/create',
        ),
        GoRoute(
          path: '/event/:eventId',
          redirect: (_, state) {
            final id = state.pathParameters['eventId']!;
            return '${AppRoutes.eventsPath}/$id';
          },
        ),
        GoRoute(
          path: '/event/:eventId/gallery',
          redirect: (_, state) {
            final id = state.pathParameters['eventId']!;
            return '${AppRoutes.eventsPath}/$id/gallery';
          },
        ),
        GoRoute(
          path: '/event/:eventId/record',
          redirect: (_, state) {
            final id = state.pathParameters['eventId']!;
            return '${AppRoutes.eventsPath}/$id/record';
          },
        ),
        GoRoute(
          path: '/event/:eventId/preview',
          redirect: (_, state) {
            final id = state.pathParameters['eventId']!;
            return '${AppRoutes.eventsPath}/$id/preview';
          },
        ),
        GoRoute(
          path: '/event/:eventId/success',
          redirect: (_, state) {
            final id = state.pathParameters['eventId']!;
            return '${AppRoutes.eventsPath}/$id/success';
          },
        ),
      ],
    );
  }
}

class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _goBranch,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library),
            label: 'Gallery',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route Error')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(message),
        ),
      ),
    );
  }
}