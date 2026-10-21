import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/applications/application_detail_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/splash_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/notifications/notifications_page.dart';
import '../../features/offers/offer_detail_page.dart';
import '../../features/offers/offers_page.dart';
import '../../features/profile/edit_profile_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/profile/skills_page.dart';
import '../../features/report/report_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/sources/source_detail_page.dart';
import '../../features/sources/sources_page.dart';
import '../auth/auth_controller.dart';
import 'app_shell.dart';
import 'routes.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Prévient le routeur quand l'état de connexion change (redirections).
class _AuthRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh();
  ref.listen(authControllerProvider, (_, _) => refresh.notify());
  ref.onDispose(refresh.dispose);

  GoRoute page(String path, Widget Function(GoRouterState state) builder) => GoRoute(
    path: path,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => builder(state),
  );

  /// Identifiant numérique d'un chemin (`/offers/42`) ; 0 si invalide (page « introuvable »).
  int id(GoRouterState state, String name) => int.tryParse(state.pathParameters[name]!) ?? 0;

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      if (auth.status == AuthStatus.unknown) {
        return location == Routes.splash ? null : Routes.splash;
      }
      if (!auth.isSignedIn) return location == Routes.login ? null : Routes.login;
      if (location == Routes.splash || location == Routes.login) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.home, builder: (_, _) => const DashboardPage())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.offers,
                builder: (_, _) => const OffersPage(),
                routes: [page(':offerId', (s) => OfferDetailPage(offerId: id(s, 'offerId')))],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.notifications, builder: (_, _) => const NotificationsPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.report, builder: (_, _) => const ReportPage())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (_, _) => const ProfilePage(),
                routes: [
                  page('edit', (_) => const EditProfilePage()),
                  page('skills', (_) => const SkillsPage()),
                  page('settings', (_) => const SettingsPage()),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.sources,
        builder: (_, _) => const SourcesPage(),
        routes: [
          GoRoute(
            path: ':sourceId',
            builder: (_, s) => SourceDetailPage(sourceId: id(s, 'sourceId')),
          ),
        ],
      ),
      GoRoute(
        path: '/applications/:applicationId',
        builder: (_, s) => ApplicationDetailPage(applicationId: id(s, 'applicationId')),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
