import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/l10n/locale_provider.dart';
import '../dashboard/screens/dashboard_screen.dart';
import '../alerts/screens/alerts_screen.dart';
import '../watchlist/screens/watchlist_screen.dart';
import '../calendar/screens/calendar_screen.dart';
import '../trades/screens/trades_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  late int _index;
  late final PageController _pageCtrl;

  static const _tabs = [
    _Tab(icon: Icons.home_rounded,           label: ('خانه', 'Home')),
    _Tab(icon: Icons.notifications_rounded,  label: ('آلرت‌ها', 'Alerts')),
    _Tab(icon: Icons.show_chart_rounded,     label: ('بازار', 'Market')),
    _Tab(icon: Icons.calendar_month_rounded, label: ('تقویم', 'Calendar')),
    _Tab(icon: Icons.candlestick_chart_rounded, label: ('معاملات', 'Trades')),
  ];

  @override
  void initState() {
    super.initState();
    _index    = widget.initialIndex;
    _pageCtrl = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _onTap(int i) {
    if (_index == i) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
    _pageCtrl.animateToPage(i,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final lang  = context.watch<LocaleProvider>().lang;
    final isDark = context.watch<ThemeProvider>().isDark;
    final isRtl  = lang == 'fa';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
        extendBody: true,
        body: PageView(
          controller:   _pageCtrl,
          physics:      const NeverScrollableScrollPhysics(),
          onPageChanged: (i) => setState(() => _index = i),
          children: const [
            DashboardScreen(),
            AlertsScreen(),
            WatchlistScreen(),
            CalendarScreen(),
            TradesScreen(),
          ],
        ),
        bottomNavigationBar: _FloatingNavBar(
          index:  _index,
          tabs:   _tabs,
          lang:   lang,
          isDark: isDark,
          onTap:  _onTap,
        ),
      ),
    );
  }
}

// ── Data ─────────────────────────────────────────────────────────────────────

class _Tab {
  const _Tab({required this.icon, required this.label});
  final IconData              icon;
  final (String fa, String en) label;
}

// ── Floating nav bar ──────────────────────────────────────────────────────────

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.index,
    required this.tabs,
    required this.lang,
    required this.isDark,
    required this.onTap,
  });

  final int           index;
  final List<_Tab>    tabs;
  final String        lang;
  final bool          isDark;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 64.h,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.07)
                    : Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(28.r),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: tabs.asMap().entries.map((e) {
                  final i      = e.key;
                  final tab    = e.value;
                  final active = index == i;
                  final label  = lang == 'fa' ? tab.label.$1 : tab.label.$2;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(vertical: 6.h),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: EdgeInsets.all(active ? 8.r : 6.r),
                              decoration: BoxDecoration(
                                gradient: active
                                    ? const LinearGradient(
                                        colors: [
                                          AppTheme.primary,
                                          Color(0xFF00E5FF),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                              child: Icon(
                                tab.icon,
                                size: active ? 20.sp : 18.sp,
                                color: active
                                    ? Colors.white
                                    : isDark
                                        ? Colors.white38
                                        : Colors.black38,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 9.sp,
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: active
                                    ? AppTheme.primary
                                    : isDark
                                        ? Colors.white38
                                        : Colors.black38,
                              ),
                              child: Text(label),
                            ),
                          ],
                        ),
                      )
                          .animate(target: active ? 1 : 0)
                          .scale(
                              begin: const Offset(1, 1),
                              end: const Offset(1.05, 1.05),
                              duration: 150.ms),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
