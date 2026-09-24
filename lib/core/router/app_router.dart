import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/forgot_password_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/register_page.dart';
import '../../features/auth/reset_password_page.dart';
import '../../features/home/home_page.dart';
import '../../features/matches/create_match_page.dart';
import '../../features/matches/finish_match_page.dart';
import '../../features/matches/invite_page.dart';
import '../../features/matches/match_lobby_page.dart';
import '../../features/matches/matches_page.dart';
import '../../features/matches/rate_match_page.dart';
import '../../features/profile/edit_profile_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/profile/public_profile_page.dart';
import '../../features/stats/stats_page.dart';
import '../../features/shell/app_shell.dart';

class AuthRefreshNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _subscription;
  AuthRefreshNotifier() {
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

GoRouter createAppRouter() {
  final refresh = AuthRefreshNotifier();
  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = Supabase.instance.client.auth.currentSession != null;
      final location = state.matchedLocation;
      final loginRoute = location == '/login' ||
          location == '/register' ||
          location == '/forgot-password';
      final recoveryRoute = location == '/reset-password';

      if (!loggedIn && !loginRoute && !recoveryRoute) {
        return '/login?next=${Uri.encodeComponent(state.uri.toString())}';
      }
      if (loggedIn && loginRoute) {
        final next = state.uri.queryParameters['next'];
        return next == null || next.isEmpty ? '/' : Uri.decodeComponent(next);
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordPage()),
      GoRoute(path: '/reset-password', builder: (_, __) => const ResetPasswordPage()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomePage()),
          GoRoute(path: '/matches', builder: (_, __) => const MatchesPage()),
          GoRoute(path: '/stats', builder: (_, __) => const StatsPage()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
          GoRoute(path: '/profile/edit', builder: (_, __) => const EditProfilePage()),
        ],
      ),
      GoRoute(path: '/matches/new', builder: (_, __) => const CreateMatchPage()),
      GoRoute(
        path: '/join/:code',
        builder: (_, state) => InvitePage(inviteCode: state.pathParameters['code']!),
      ),
      GoRoute(
        path: '/match/:id',
        builder: (_, state) => MatchLobbyPage(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/match/:id/finish',
        builder: (_, state) => FinishMatchPage(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/match/:id/rate',
        builder: (_, state) => RateMatchPage(matchId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/player/:id',
        builder: (_, state) => PublicProfilePage(userId: state.pathParameters['id']!),
      ),
    ],
  );
}
