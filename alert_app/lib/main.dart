import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/services/notification_service.dart';
import 'core/l10n/locale_provider.dart';
import 'core/router/app_router.dart';
import 'features/alerts/providers/alert_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/calendar/providers/calendar_provider.dart';
import 'features/trades/providers/trade_provider.dart';
import 'features/settings/providers/notification_settings_provider.dart';
import 'features/watchlist/providers/watchlist_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();

  // Set up deep link: FCM notification tap → navigate to alert
  NotificationService.instance.onNotificationTap = (payload) {
    final type     = payload['type'] as String?;
    final alertId  = payload['alert_id'];
    if (type == 'alert_triggered' && alertId != null) {
      final id = int.tryParse(alertId.toString());
      if (id != null) {
        AppRouter.router.go('/alerts', extra: 'highlight:$id');
      }
    }
  };

  runApp(const ZAlertApp());
}

class ZAlertApp extends StatelessWidget {
  const ZAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AlertProvider()),
        ChangeNotifierProvider(create: (_) => CalendarProvider()),
        ChangeNotifierProvider(create: (_) => TradeProvider()),
        ChangeNotifierProvider(create: (_) => NotificationSettingsProvider()),
        ChangeNotifierProvider(create: (_) => WatchlistProvider()),   // NEW
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (_, themeProvider, localeProvider, __) {
          return ScreenUtilInit(
            designSize: const Size(375, 812),
            minTextAdapt: true,
            builder: (_, __) => MaterialApp.router(
              title: 'ZAlert',
              debugShowCheckedModeBanner: false,
              theme:      AppTheme.lightTheme,
              darkTheme:  AppTheme.darkTheme,
              themeMode:  themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
              routerConfig: AppRouter.router,
              locale: Locale(localeProvider.lang),
            ),
          );
        },
      ),
    );
  }
}
