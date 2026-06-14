import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/shimmer_widgets.dart';
import '../../alerts/providers/alert_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../calendar/providers/calendar_provider.dart';
import '../widgets/market_price_card.dart';
import '../widgets/alert_summary_card.dart';
import '../widgets/calendar_preview_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Live prices — refreshed every 15 s (matches server CHECK_INTERVAL)
  static const _refreshInterval = Duration(seconds: 15);
  static const _popularSymbols  = [
    ('🥇', 'XAUUSD', 'طلا / Gold'),
    ('💶', 'EURUSD', 'EUR/USD'),
    ('🔷', 'BTCUSD', 'Bitcoin'),
    ('🫙', 'USOIL',  'نفت / Oil'),
    ('📈', 'US500',  'S&P 500'),
    ('🥈', 'XAGUSD', 'نقره / Silver'),
  ];

  final Map<String, double> _prices    = {};
  final Map<String, double> _prevPrices = {};
  bool  _loadingPrices = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchAll();
    _timer = Timer.periodic(_refreshInterval, (_) => _fetchAll());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.userId != null) {
        context.read<AlertProvider>().loadAlerts(auth.userId!);
        context.read<CalendarProvider>().load();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    for (final (_, sym, _) in _popularSymbols) {
      _fetchPrice(sym);
    }
  }

  Future<void> _fetchPrice(String symbol) async {
    try {
      final data  = await ApiService.instance.getPrice(symbol);
      final price = (data['price'] as num?)?.toDouble();
      if (price != null && mounted) {
        setState(() {
          _prevPrices[symbol] = _prices[symbol] ?? price;
          _prices[symbol]     = price;
          _loadingPrices      = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPrices = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang  = context.watch<LocaleProvider>().lang;
    final isRtl = lang == 'fa';
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDark;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
        body: RefreshIndicator(
          onRefresh: () async {
            await _fetchAll();
            final auth = context.read<AuthProvider>();
            if (auth.userId != null) {
              await context.read<AlertProvider>().loadAlerts(auth.userId!);
              await context.read<CalendarProvider>().load();
            }
          },
          color: AppTheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildAppBar(context, isDark, lang),
              SliverToBoxAdapter(child: SizedBox(height: 8.h)),

              // ── Market Overview ────────────────────────────────────────
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: lang == 'fa' ? 'قیمت‌های لحظه‌ای' : 'Live Market',
                  icon: Icons.show_chart_rounded,
                  onSeeAll: () => context.push('/watchlist'),
                  seeAllLabel: lang == 'fa' ? 'واچ‌لیست' : 'Watchlist',
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 110.h,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    separatorBuilder: (_, __) => SizedBox(width: 10.w),
                    itemCount: _popularSymbols.length,
                    itemBuilder: (_, i) {
                      final (emoji, sym, label) = _popularSymbols[i];
                      if (_loadingPrices) return const ShimmerMarketCard();
                      return MarketPriceCard(
                        emoji: emoji,
                        symbol: sym,
                        label: label,
                        price: _prices[sym],
                        prevPrice: _prevPrices[sym],
                        lang: lang,
                        onTap: () => context.push('/watchlist'),
                      ).animate().fadeIn(delay: (i * 80).ms);
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 16.h)),

              // ── My Alerts Summary ──────────────────────────────────────
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: lang == 'fa' ? 'آلرت‌های من' : 'My Alerts',
                  icon: Icons.notifications_active_outlined,
                  onSeeAll: () => context.go('/alerts'),
                  seeAllLabel: lang == 'fa' ? 'همه' : 'All',
                ),
              ),
              SliverToBoxAdapter(
                child: AlertSummaryCard(
                  lang: lang,
                  isDark: isDark,
                  onAddAlert: () => context.push('/alerts/add'),
                  onViewAll:  () => context.go('/alerts'),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 16.h)),

              // ── Calendar Preview ───────────────────────────────────────
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: lang == 'fa' ? 'تقویم اقتصادی امروز' : "Today's Calendar",
                  icon: Icons.calendar_today_outlined,
                  onSeeAll: () => context.go('/alerts', extra: 'calendar'),
                  seeAllLabel: lang == 'fa' ? 'همه رویدادها' : 'All events',
                ),
              ),
              SliverToBoxAdapter(
                child: CalendarPreviewCard(lang: lang, isDark: isDark),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 24.h)),
            ],
          ),
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext ctx, bool isDark, String lang) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      elevation: 0,
      title: Row(
        children: [
          Text(
            'ZAlert',
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
              fontFamily: 'TexGyreAdventor',
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(
              lang == 'fa' ? 'داشبورد' : 'Dashboard',
              style: TextStyle(
                fontSize: 11.sp,
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          onPressed: () => ctx.read<ThemeProvider>().toggle(),
        ),
        IconButton(
          icon: Icon(Icons.person_outline_rounded,
              color: isDark ? Colors.white70 : Colors.black54),
          onPressed: () => ctx.go('/alerts'),
        ),
        SizedBox(width: 4.w),
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.onSeeAll,
    required this.seeAllLabel,
  });

  final String title;
  final IconData icon;
  final VoidCallback onSeeAll;
  final String seeAllLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        children: [
          Icon(icon, size: 18.sp,
              color: isDark ? Colors.white70 : Colors.black54),
          SizedBox(width: 6.w),
          Text(
            title,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              seeAllLabel,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
