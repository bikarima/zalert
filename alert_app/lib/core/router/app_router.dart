import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/alerts/screens/alerts_screen.dart';
import '../../features/alerts/screens/add_alert_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/language/screens/language_screen.dart';
import '../../features/calculator/screens/calculator_screen.dart';
import '../../features/trades/screens/trades_screen.dart';
import '../../features/announcements/screens/announcements_screen.dart';
import '../../features/settings/screens/notification_settings_screen.dart';

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) async {
      final auth = context.read<AuthProvider>();
      final prefs = await SharedPreferences.getInstance();

      final langSet = prefs.getString('lang') != null;
      final onboardingDone = prefs.getBool('onboarding_done') ?? false;
      final isLoggedIn = auth.isLoggedIn;
      final loc = state.matchedLocation;

      if (!langSet && loc != '/language') return '/language';
      if (langSet && !onboardingDone && loc != '/onboarding') return '/onboarding';
      if (langSet && onboardingDone && !isLoggedIn && loc != '/login') return '/login';
      if (isLoggedIn && (loc == '/login' || loc == '/splash')) return '/alerts';

      return null;
    },
    routes: [
      GoRoute(path: '/splash',          builder: (_, __) => const _SplashScreen()),
      GoRoute(path: '/language',        builder: (_, __) => const LanguageScreen()),
      GoRoute(path: '/onboarding',      builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login',           builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/alerts',          builder: (_, __) => const AlertsScreen()),
      GoRoute(path: '/add-alert',       builder: (_, __) => const AddAlertScreen()),
      GoRoute(path: '/calculator',         builder: (_, __) => const CalculatorScreen()),
      GoRoute(path: '/trades',             builder: (_, __) => const TradesScreen()),
      GoRoute(path: '/announcements',      builder: (_, __) => const AnnouncementsScreen()),
      GoRoute(path: '/notification-settings', builder: (_, __) => const NotificationSettingsScreen()),
    ],
  );
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
    );
  }
}
