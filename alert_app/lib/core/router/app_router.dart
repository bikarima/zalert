import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/alerts/screens/alert_history_screen.dart';
import '../../features/alerts/screens/alerts_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/language/screens/language_screen.dart';
import '../../features/settings/screens/notification_settings_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/main/main_shell.dart';

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) async {
      final auth  = context.read<AuthProvider>();
      final prefs = await SharedPreferences.getInstance();
      final loc   = state.fullPath ?? state.uri.toString();

      final langSet        = prefs.getString('lang') != null;
      final onboardingDone = prefs.getBool('onboarding_done') ?? false;
      final loggedIn       = auth.isLoggedIn;

      // Sequential — each step only evaluated when prior steps pass
      if (!langSet)        return loc == '/language'   ? null : '/language';
      if (!onboardingDone) return loc == '/onboarding' ? null : '/onboarding';
      if (!loggedIn)       return loc == '/login'      ? null : '/login';

      // Logged in on auth screens → home shell
      if (loc == '/splash' || loc == '/login' ||
          loc == '/language' || loc == '/onboarding') {
        return '/home';
      }

      return null;
    },
    routes: [
      // ── Auth flow ────────────────────────────────────────────────────
      GoRoute(path: '/splash',    builder: (_, __) => const _Splash()),
      GoRoute(path: '/language',  builder: (_, __) => const LanguageScreen()),
      GoRoute(path: '/onboarding',builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login',     builder: (_, __) => const LoginScreen()),

      // ── Main shell (bottom nav) ──────────────────────────────────────
      GoRoute(
        path: '/home',
        builder: (_, __) => const MainShell(initialIndex: 0),
      ),

      // Tab deep-links — open shell at the right tab
      GoRoute(path: '/dashboard',
          builder: (_, __) => const MainShell(initialIndex: 0)),
      GoRoute(path: '/alerts',
          builder: (_, __) => const MainShell(initialIndex: 1)),
      GoRoute(path: '/watchlist',
          builder: (_, __) => const MainShell(initialIndex: 2)),
      GoRoute(path: '/calendar',
          builder: (_, __) => const MainShell(initialIndex: 3)),
      GoRoute(path: '/trades',
          builder: (_, __) => const MainShell(initialIndex: 4)),

      // ── Stacked routes (push on top of shell) ───────────────────────
      GoRoute(
        path: '/alerts/add',
        builder: (_, __) => const _AlertsWithSheet(),
      ),
      GoRoute(
        path: '/alerts/history',
        builder: (_, __) => const AlertHistoryScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (_, __) => const NotificationSettingsScreen(),
      ),
    ],
  );
}

// Splash — invisible, just triggers redirect
class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

// Open alerts tab + immediately show add sheet
class _AlertsWithSheet extends StatefulWidget {
  const _AlertsWithSheet();
  @override
  State<_AlertsWithSheet> createState() => _AlertsWithSheetState();
}

class _AlertsWithSheetState extends State<_AlertsWithSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go('/alerts');
    });
  }

  @override
  Widget build(BuildContext context) =>
      const MainShell(initialIndex: 1);
}
