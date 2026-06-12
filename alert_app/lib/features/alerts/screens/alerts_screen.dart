import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:badges/badges.dart' as badges;
import '../providers/alert_provider.dart';
import '../widgets/alert_card.dart';
import '../widgets/price_ticker_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../../calendar/screens/calendar_screen.dart';
import '../../trades/screens/trades_screen.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  int _currentTab = 0;
  int _unreadAnnouncements = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _checkUnreadAnnouncements();
    });
  }

  void _loadData() {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;
    context.read<AlertProvider>().loadAlerts(userId, includeTriggered: true);
  }

  Future<void> _checkUnreadAnnouncements() async {
    try {
      final readIds = await StorageService.instance.getReadAnnouncementIds();
      final raw     = await ApiService.instance.getAnnouncements();
      final unread  = raw.where((j) {
        final id = j['id']?.toString() ?? '';
        return !readIds.contains(id);
      }).length;
      if (mounted) setState(() => _unreadAnnouncements = unread);
    } catch (_) {}
  }

  Future<void> _delete(BuildContext ctx, int alertId) async {
    final userId = ctx.read<AuthProvider>().userId!;
    await ctx.read<AlertProvider>().deleteAlert(alertId, userId);
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final provider = context.watch<AlertProvider>();
    final lang     = context.watch<LocaleProvider>().lang;
    final isRtl    = lang == 'fa';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.bg(context),
        body: IndexedStack(
          index: _currentTab,
          children: [
            // ── تب ۰: آلرت‌های فعال ───────────────────────────────
            _ActiveAlertsTab(
              alerts: provider.activeAlerts,
              loading: provider.status == AlertStatus.loading,
              lang: lang,
              unreadAnnouncements: _unreadAnnouncements,
              onDelete: (id) => _delete(context, id),
              onRefresh: _loadData,
            ),
            // ── تب ۱: triggered ───────────────────────────────────
            _TriggeredAlertsTab(
              alerts: provider.triggeredAlerts,
              loading: provider.status == AlertStatus.loading,
              lang: lang,
              onRefresh: _loadData,
            ),
            // ── تب ۲: تقویم اقتصادی ───────────────────────────────
            const CalendarScreen(),
            // ── تب ۳: معاملات ─────────────────────────────────────
            const TradesScreen(),
            // ── تب ۴: پروفایل ─────────────────────────────────────
            _SettingsTab(
              lang: lang,
              username: auth.username,
              onLogout: () async {
                await auth.logout();
                if (context.mounted) context.go('/login');
              },
              onChangeLang: () => context.go('/language'),
            ),
          ],
        ),
        bottomNavigationBar: _BottomNav(
          currentIndex: _currentTab,
          triggeredCount: provider.triggeredAlerts.length,
          lang: lang,
          onTap: (i) => setState(() => _currentTab = i),
        ),
        floatingActionButton: _currentTab == 0
            ? FloatingActionButton.extended(
                onPressed: () => context.push('/add-alert'),
                icon: Icon(Icons.add_rounded, size: 20.sp),
                label: Text(AppStrings.t(AppStrings.newAlert, lang),
                    style: TextStyle(fontSize: 13.sp)),
                backgroundColor: AppTheme.primary,
              ).animate().scale(duration: 300.ms, curve: Curves.elasticOut)
            : null,
      ),
    );
  }
}

// ── Bottom Navigation ─────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final int triggeredCount;
  final String lang;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.triggeredCount,
    required this.lang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border(top: BorderSide(color: AppTheme.divider(context))),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.notifications_outlined,
                activeIcon: Icons.notifications_rounded,
                label: AppStrings.t(AppStrings.active, lang),
                active: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.check_circle_outline_rounded,
                activeIcon: Icons.check_circle_rounded,
                label: AppStrings.t(AppStrings.triggered, lang),
                active: currentIndex == 1,
                badge: triggeredCount > 0 ? triggeredCount.toString() : null,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.calendar_today_outlined,
                activeIcon: Icons.calendar_today_rounded,
                label: lang == 'fa' ? 'تقویم' : 'Calendar',
                active: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.bar_chart_rounded,
                activeIcon: Icons.bar_chart_rounded,
                label: lang == 'fa' ? 'معاملات' : 'Trades',
                active: currentIndex == 3,
                onTap: () => onTap(3),
              ),              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: lang == 'fa' ? 'پروفایل' : 'Profile',
                active: currentIndex == 4,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final String? badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            badges.Badge(
              showBadge: badge != null,
              badgeContent: Text(badge ?? '',
                  style: TextStyle(color: Colors.white, fontSize: 9.sp)),
              badgeStyle: const badges.BadgeStyle(badgeColor: AppTheme.red),
              child: Icon(
                active ? activeIcon : icon,
                color: active ? AppTheme.primary : AppTheme.textSec(context),
                size: 22.sp,
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              label,
              style: TextStyle(
                color: active ? AppTheme.primary : AppTheme.textSec(context),
                fontSize: 10.sp,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Active Alerts Tab ─────────────────────────────────────────────────────────

class _ActiveAlertsTab extends StatelessWidget {
  final List alerts;
  final bool loading;
  final String lang;
  final int unreadAnnouncements;
  final Function(int) onDelete;
  final VoidCallback onRefresh;

  const _ActiveAlertsTab({
    required this.alerts, required this.loading, required this.lang,
    required this.unreadAnnouncements,
    required this.onDelete, required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 160.h,
          floating: false,
          pinned: true,
          backgroundColor: AppTheme.bg(context),
          flexibleSpace: FlexibleSpaceBar(
            background: _HeaderWidget(lang: lang),
          ),
          title: Text(AppStrings.t(AppStrings.myAlerts, lang),
              style: TextStyle(
                  color: AppTheme.text(context),
                  fontWeight: FontWeight.bold, fontSize: 16.sp)),
          actions: [
            // دکمه اطلاعیه‌ها
            IconButton(
              icon: badges.Badge(
                showBadge: unreadAnnouncements > 0,
                badgeContent: Text(
                  '$unreadAnnouncements',
                  style: TextStyle(color: Colors.white, fontSize: 9.sp),
                ),
                badgeStyle: const badges.BadgeStyle(badgeColor: AppTheme.red),
                child: Icon(Icons.notifications_outlined,
                    size: 20.sp, color: AppTheme.text(context)),
              ),
              onPressed: () => context.push('/announcements'),
            ),
            IconButton(
                icon: Icon(Icons.refresh_rounded, size: 20.sp),
                onPressed: onRefresh),
          ],
        ),
        SliverToBoxAdapter(child: PriceTickerWidget(lang: lang)),
        SliverToBoxAdapter(child: SizedBox(height: 6.h)),
        loading
            ? const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()))
            : alerts.isEmpty
                ? SliverFillRemaining(
                    child: _EmptyState(
                      icon: Icons.notifications_none_rounded,
                      text: AppStrings.t(AppStrings.noActiveAlerts, lang),
                    ))
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => Slidable(
                        key: ValueKey(alerts[i].id),
                        endActionPane: ActionPane(
                          motion: const BehindMotion(),
                          extentRatio: 0.22,
                          children: [
                            SlidableAction(
                              onPressed: (_) => onDelete(alerts[i].id),
                              backgroundColor: AppTheme.red,
                              foregroundColor: Colors.white,
                              icon: Icons.delete_rounded,
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                          ],
                        ),
                        child: AlertCard(alert: alerts[i], lang: lang)
                            .animate()
                            .fadeIn(duration: 300.ms,
                                delay: Duration(milliseconds: i * 60)),
                      ),
                      childCount: alerts.length,
                    )),
        SliverToBoxAdapter(child: SizedBox(height: 90.h)),
      ],
    );
  }
}

// ── Triggered Alerts Tab ──────────────────────────────────────────────────────

class _TriggeredAlertsTab extends StatelessWidget {
  final List alerts;
  final bool loading;
  final String lang;
  final VoidCallback onRefresh;

  const _TriggeredAlertsTab({
    required this.alerts, required this.loading,
    required this.lang, required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: AppTheme.bg(context),
          title: Text(AppStrings.t(AppStrings.triggered, lang),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
          actions: [
            IconButton(
                icon: Icon(Icons.refresh_rounded, size: 20.sp),
                onPressed: onRefresh),
          ],
        ),
        loading
            ? const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()))
            : alerts.isEmpty
                ? SliverFillRemaining(
                    child: _EmptyState(
                      icon: Icons.check_circle_outline_rounded,
                      text: AppStrings.t(AppStrings.noTriggeredAlerts, lang),
                    ))
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => AlertCard(
                        alert: alerts[i], lang: lang, isTriggered: true,
                      ).animate().fadeIn(
                          duration: 300.ms,
                          delay: Duration(milliseconds: i * 60)),
                      childCount: alerts.length,
                    )),
        SliverToBoxAdapter(child: SizedBox(height: 32.h)),
      ],
    );
  }
}

// ── Settings Tab ──────────────────────────────────────────────────────────────

class _SettingsTab extends StatelessWidget {
  final String lang;
  final String? username;
  final VoidCallback onLogout;
  final VoidCallback onChangeLang;

  const _SettingsTab({
    required this.lang, required this.username,
    required this.onLogout, required this.onChangeLang,
  });

  void _showSyncTelegramDialog(BuildContext context) {
    final ctrl = TextEditingController();
    final auth = context.read<AuthProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card(context),
        title: Text(
          lang == 'fa' ? '🔗 Sync با تلگرام' : '🔗 Sync with Telegram',
          style: TextStyle(
              color: AppTheme.text(context),
              fontSize: 16.sp, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang == 'fa'
                  ? 'آیدی عددی تلگرامت رو وارد کن تا حسابت به تلگرام لینک بشه:'
                  : 'Enter your Telegram numeric ID to link your account:',
              style: TextStyle(
                  color: AppTheme.textSec(context), fontSize: 12.sp),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                  color: AppTheme.text(context), fontSize: 14.sp),
              decoration: InputDecoration(
                labelText: lang == 'fa'
                    ? 'آیدی عددی تلگرام'
                    : 'Telegram Numeric ID',
                hintText: '123456789',
                prefixIcon: Icon(Icons.telegram,
                    color: AppTheme.primary, size: 18.sp),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang == 'fa' ? 'انصراف' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final id = int.tryParse(ctrl.text.trim());
              if (id == null) return;
              Navigator.pop(ctx);
              final ok = await auth.linkToTelegram(id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                    ok
                        ? (lang == 'fa'
                            ? '✅ با موفقیت به تلگرام لینک شد'
                            : '✅ Successfully linked to Telegram')
                        : (auth.error ?? 'Error'),
                  ),
                  backgroundColor: ok ? AppTheme.green : AppTheme.red,
                ));
              }
            },
            child: Text(lang == 'fa' ? 'لینک کن' : 'Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRtl         = lang == 'fa';
    final themeProvider = context.watch<ThemeProvider>();
    final isDark        = themeProvider.isDark;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppTheme.bg(context),
            title: Text(lang == 'fa' ? 'پروفایل' : 'Profile',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(height: 20.h),
                Container(
                  width: 70.w, height: 70.w,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, Color(0xFF9C27B0)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: AppTheme.primary.withOpacity(0.4),
                      blurRadius: 16.r, offset: const Offset(0, 6),
                    )],
                  ),
                  child: Icon(Icons.person_rounded, size: 32.sp, color: Colors.white),
                ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
                SizedBox(height: 10.h),
                if (username != null)
                  Text(username!,
                      style: TextStyle(
                          color: AppTheme.text(context),
                          fontSize: 15.sp, fontWeight: FontWeight.bold)),
                SizedBox(height: 24.h),

                // Dark/Light toggle
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                  child: Material(
                    color: AppTheme.card(context),
                    borderRadius: BorderRadius.circular(14.r),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                      child: Row(children: [
                        Container(
                          width: 36.w, height: 36.w,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(
                            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            color: AppTheme.primary, size: 17.sp,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          lang == 'fa'
                              ? (isDark ? 'حالت شب' : 'حالت روز')
                              : (isDark ? 'Dark Mode' : 'Light Mode'),
                          style: TextStyle(color: AppTheme.text(context),
                              fontSize: 13.sp, fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        Switch(value: isDark, onChanged: (_) => themeProvider.toggle()),
                      ]),
                    ),
                  ),
                ).animate().fadeIn(duration: 200.ms),

                _SettingItem(
                  icon: Icons.calculate_outlined,
                  title: lang == 'fa' ? 'ماشین حساب' : 'Calculator',
                  onTap: () => context.push('/calculator'),
                ),
                _SettingItem(
                  icon: Icons.language_rounded,
                  title: AppStrings.t(AppStrings.selectLanguage, lang),
                  onTap: onChangeLang,
                ),

                // ── تنظیمات نوتیفیکیشن ────────────────────────────
                _SettingItem(
                  icon: Icons.notifications_outlined,
                  title: lang == 'fa' ? 'تنظیمات اعلان‌ها' : 'Notification Settings',
                  onTap: () => context.push('/notification-settings'),
                ),

                // ── کانال تلگرام ──────────────────────────────────
                _TelegramChannelCard(lang: lang),
                SizedBox(height: 8.h),

                // لینک تلگرام
                _SettingItem(
                  icon: Icons.link_rounded,
                  title: lang == 'fa'
                      ? '🔗 Sync با تلگرام'
                      : '🔗 Sync with Telegram',
                  onTap: () => _showSyncTelegramDialog(context),
                ),

                // معاملات
                _SettingItem(
                  icon: Icons.receipt_long_outlined,
                  title: lang == 'fa' ? '📊 معاملات من' : '📊 My Trades',
                  onTap: () => context.push('/trades'),
                ),

                // ── تست Push Notification ─────────────────────────
                _TestNotificationCard(lang: lang),
                SizedBox(height: 8.h),

                _SettingItem(
                  icon: Icons.logout_rounded,
                  title: AppStrings.t(AppStrings.logout, lang),
                  color: AppTheme.red,
                  onTap: onLogout,
                ),
                SizedBox(height: 32.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final VoidCallback onTap;

  const _SettingItem({
    required this.icon, required this.title, required this.onTap, this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.text(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: Material(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            child: Row(children: [
              Container(
                width: 36.w, height: 36.w,
                decoration: BoxDecoration(
                  color: c.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, color: c, size: 17.sp),
              ),
              SizedBox(width: 12.w),
              Text(title, style: TextStyle(color: c, fontSize: 13.sp,
                  fontWeight: FontWeight.w500)),
              const Spacer(),
              Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textSec(context), size: 18.sp),
            ]),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

// ── Telegram Channel Card ─────────────────────────────────────────────────────

class _TelegramChannelCard extends StatelessWidget {
  final String lang;
  const _TelegramChannelCard({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          onTap: () async {
            final uri = Uri.parse('https://t.me/ZAlertPlus');
            try {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (_) {}
          },
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0088CC), Color(0xFF005F8F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0088CC).withOpacity(0.3),
                  blurRadius: 12.r,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(children: [
              Container(
                width: 44.w, height: 44.w,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.telegram, color: Colors.white, size: 24.sp),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang == 'fa' ? 'کانال تلگرام ما' : 'Our Telegram Channel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '@ZAlertPlus',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.7), size: 16.sp),
            ]),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

// ── Test Push Notification ────────────────────────────────────────────────────

class _TestNotificationCard extends StatefulWidget {
  final String lang;
  const _TestNotificationCard({required this.lang});

  @override
  State<_TestNotificationCard> createState() => _TestNotificationCardState();
}

class _TestNotificationCardState extends State<_TestNotificationCard> {
  bool _sending = false;
  String? _status;
  String? _token;

  @override
  void initState() {
    super.initState();
    _token = NotificationService.instance.fcmToken;
  }

  Future<void> _sendTest() async {
    setState(() { _sending = true; _status = null; });

    try {
      // نوتیف local بفرست
      await NotificationService.instance.showTestNotification(widget.lang);
      setState(() {
        _status  = widget.lang == 'fa'
            ? '✅ نوتیف ارسال شد — اگه دیدید کار میکنه!'
            : '✅ Notification sent — if you see it, it works!';
        _sending = false;
      });
    } catch (e) {
      setState(() {
        _status  = '❌ Error: $e';
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang  = widget.lang;
    final isRtl = lang == 'fa';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Column(
          crossAxisAlignment: isRtl
              ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 36.w, height: 36.w,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.notifications_active_outlined,
                    color: AppTheme.primary, size: 18.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: isRtl
                      ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang == 'fa' ? 'تست Push Notification' : 'Test Push Notification',
                      style: TextStyle(
                        color: AppTheme.text(context),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_token != null)
                      Text(
                        'FCM: ${_token!.substring(0, 20)}...',
                        style: TextStyle(
                            color: AppTheme.textSec(context), fontSize: 9.sp),
                      )
                    else
                      Text(
                        lang == 'fa' ? '⚠️ توکن دریافت نشده' : '⚠️ No FCM token',
                        style: TextStyle(color: AppTheme.orange, fontSize: 10.sp),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _sending ? null : _sendTest,
                child: AnimatedContainer(
                  duration: 200.ms,
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppTheme.primary, Color(0xFF9C27B0)]),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: _sending
                      ? SizedBox(width: 16.w, height: 16.w,
                          child: const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          lang == 'fa' ? 'تست' : 'Test',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ]),

            if (_status != null) ...[
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: _status!.startsWith('✅')
                      ? AppTheme.green.withOpacity(0.1)
                      : AppTheme.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(_status!,
                    style: TextStyle(
                      color: _status!.startsWith('✅')
                          ? AppTheme.green : AppTheme.red,
                      fontSize: 11.sp,
                    )),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _HeaderWidget extends StatelessWidget {
  final String lang;
  const _HeaderWidget({required this.lang});

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final provider = context.watch<AlertProvider>();
    final isRtl    = lang == 'fa';
    final isDark   = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF1A1A35), AppTheme.darkBg]
              : [const Color(0xFFEEEEFF), AppTheme.lightBg],
        ),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 72.h, 20.w, 12.h),
      child: Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lang == 'fa'
                      ? 'سلام${auth.username != null ? '، ${auth.username}' : ''} 👋'
                      : 'Hello${auth.username != null ? ', ${auth.username}' : ''} 👋',
                  style: TextStyle(color: AppTheme.textSec(context), fontSize: 12.sp),
                ),
                SizedBox(height: 3.h),
                Text(
                  lang == 'fa' ? 'آلرت‌های فعال' : 'Active Alerts',
                  style: TextStyle(color: AppTheme.text(context),
                      fontSize: 18.sp, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppTheme.primary, Color(0xFF9C27B0)]),
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [BoxShadow(
                color: AppTheme.primary.withOpacity(0.4),
                blurRadius: 10.r, offset: const Offset(0, 4),
              )],
            ),
            child: Text('${provider.activeAlerts.length}',
                style: TextStyle(color: Colors.white,
                    fontSize: 20.sp, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70.w, height: 70.w,
            decoration: BoxDecoration(
              color: AppTheme.surface(context),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: Icon(icon, size: 30.sp, color: AppTheme.textSec(context)),
          ),
          SizedBox(height: 14.h),
          Text(text, style: TextStyle(color: AppTheme.textSec(context), fontSize: 13.sp)),
        ],
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0, duration: 400.ms),
    );
  }
}
