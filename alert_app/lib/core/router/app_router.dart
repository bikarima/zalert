import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/alerts/screens/alerts_screen.dart';
import '../../features/alerts/screens/add_alert_screen.dart';
import '../../features/alerts/screens/alert_history_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/language/screens/language_screen.dart';
import '../../features/calculator/screens/calculator_screen.dart';
import '../../features/trades/screens/trades_screen.dart';
import '../../features/announcements/screens/announcements_screen.dart';
import '../../features/settings/screens/notification_settings_screen.dart';
import '../../features/calendar/screens/calendar_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/watchlist/screens/watchlist_screen.dart';

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) async {
      final auth   = context.read<AuthProvider>();
      final prefs  = await SharedPreferences.getInstance();
      final loc    = state.fullPath ?? state.uri.toString();

      final langSet       = prefs.getString('lang') != null;
      final onboardingDone = prefs.getBool('onboarding_done') ?? false;
      final loggedIn      = auth.isLoggedIn;

      // شرایط باید sequential باشن — هر سطح فقط وقتی بررسی میشه که سطح قبلی ok باشه

      // 1. زبان انتخاب نشده → فقط /language مجاز است
      if (!langSet) {
        return loc == '/language' ? null : '/language';
      }

      // 2. Onboarding انجام نشده → فقط /onboarding مجاز است
      if (!onboardingDone) {
        return loc == '/onboarding' ? null : '/onboarding';
      }

      // 3. لاگین نیست → فقط /login مجاز است
      if (!loggedIn) {
        return loc == '/login' ? null : '/login';
      }

      // 4. لاگین شده و روی صفحه اوت → برو داشبورد
      if (loc == '/splash' || loc == '/login' ||
          loc == '/language' || loc == '/onboarding') {
        return '/dashboard';
      }

      return null;
    },
    routes: [

      // ── Splash / auth flow ─────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        builder: (_, __) => const _SplashScreen(),
      ),
      GoRoute(
        path: '/language',
        builder: (_, __) => const LanguageScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),

      // ── Main app ───────────────────────────────────────────────────────
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/alerts',
        builder: (_, state) {
          // extra = 'highlight:<id>' when navigating from push notification
          final extra     = state.extra as String?;
          // Store highlight ID in context extras for AlertsScreen to read
          return const AlertsScreen();
        },
        routes: [
          GoRoute(
            path: 'add',
            builder: (_, __) => const AddAlertScreen(),
          ),
          GoRoute(
            path: 'history',
            builder: (_, __) => const AlertHistoryScreen(),
          ),
        ],
      ),

      // ── Watchlist ──────────────────────────────────────────────────────
      GoRoute(
        path: '/watchlist',
        builder: (_, __) => const WatchlistScreen(),
      ),

      // ── Calendar ───────────────────────────────────────────────────────
      GoRoute(
        path: '/calendar',
        builder: (_, __) => const CalendarScreen(),
      ),

      // ── Other screens ──────────────────────────────────────────────────
      GoRoute(
        path: '/trades',
        builder: (_, __) => const TradesScreen(),
      ),
      GoRoute(
        path: '/announcements',
        builder: (_, __) => const AnnouncementsScreen(),
      ),
      GoRoute(
        path: '/calculator',
        builder: (_, __) => const CalculatorScreen(),
      ),
      GoRoute(
        path: '/settings/notifications',
        builder: (_, __) => const NotificationSettingsScreen(),
      ),
    ],
  );
}

// ── Splash: invisible, just triggers redirect ─────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
