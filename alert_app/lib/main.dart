import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/services/notification_service.dart';
import 'core/l10n/locale_provider.dart';
import 'features/alerts/providers/alert_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/calendar/providers/calendar_provider.dart';
import 'features/trades/providers/trade_provider.dart';
import 'features/settings/providers/notification_settings_provider.dart';
import 'core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  runApp(const AlertApp());
}

class AlertApp extends StatelessWidget {
  const AlertApp({super.key});

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
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (_, themeProvider, localeProvider, __) {
          final fontFamily = AppTheme.fontFamily(localeProvider.lang);
          return ScreenUtilInit(
            designSize: const Size(390, 844),
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (context, child) => MaterialApp.router(
              title: 'Alert',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light.copyWith(
                textTheme: AppTheme.light.textTheme.apply(fontFamily: fontFamily),
              ),
              darkTheme: AppTheme.dark.copyWith(
                textTheme: AppTheme.dark.textTheme.apply(fontFamily: fontFamily),
              ),
              themeMode: themeProvider.mode,
              routerConfig: AppRouter.router,
            ),
          );
        },
      ),
    );
  }
}
