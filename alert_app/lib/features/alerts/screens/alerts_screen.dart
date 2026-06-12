import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:badges/badges.dart' as badges;
import '../providers/alert_provider.dart';
import '../widgets/alert_card.dart';
import '../widgets/price_ticker_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;
    context.read<AlertProvider>().loadAlerts(userId, includeTriggered: true);
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
    final s        = AppStrings.t;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: IndexedStack(
          index: _currentTab,
          children: [
            // ── تب ۱: آلرت‌های فعال ───────────────────────────────
            _ActiveAlertsTab(
              alerts: provider.activeAlerts,
              loading: provider.status == AlertStatus.loading,
              lang: lang,
              onDelete: (id) => _delete(context, id),
              onRefresh: _loadData,
            ),

            // ── تب ۲: triggered ───────────────────────────────────
            _TriggeredAlertsTab(
              alerts: provider.triggeredAlerts,
              loading: provider.status == AlertStatus.loading,
              lang: lang,
              onRefresh: _loadData,
            ),

            // ── تب ۳: تنظیمات ─────────────────────────────────────
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

        // ── Bottom Navigation ──────────────────────────────────────
        bottomNavigationBar: _BottomNav(
          currentIndex: _currentTab,
          triggeredCount: provider.triggeredAlerts.length,
          lang: lang,
          onTap: (i) => setState(() => _currentTab = i),
        ),

        // ── FAB ───────────────────────────────────────────────────
        floatingActionButton: _currentTab == 0
            ? FloatingActionButton.extended(
                onPressed: () => context.push('/add-alert'),
                icon: const Icon(Icons.add_rounded),
                label: Text(s(AppStrings.newAlert, lang)),
                backgroundColor: AppTheme.primary,
              ).animate().scale(duration: 300.ms, curve: Curves.elasticOut)
            : null,
      ),
    );
  }
}

// ── Bottom Navigation ──────────────────────────────────────────────────────────

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
        color: AppTheme.surface,
        border: const Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
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
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: lang == 'fa' ? 'پروفایل' : 'Profile',
                active: currentIndex == 2,
                onTap: () => onTap(2),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            badges.Badge(
              showBadge: badge != null,
              badgeContent: Text(badge ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 10)),
              badgeStyle: const badges.BadgeStyle(badgeColor: AppTheme.red),
              child: Icon(
                active ? activeIcon : icon,
                color: active ? AppTheme.primary : AppTheme.textSecond,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? AppTheme.primary : AppTheme.textSecond,
                fontSize: 11,
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
  final Function(int) onDelete;
  final VoidCallback onRefresh;

  const _ActiveAlertsTab({
    required this.alerts,
    required this.loading,
    required this.lang,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── Header ─────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 200,
          floating: false,
          pinned: true,
          backgroundColor: AppTheme.background,
          flexibleSpace: FlexibleSpaceBar(
            background: _HeaderWidget(lang: lang),
          ),
          title: Text(
            AppStrings.t(AppStrings.myAlerts, lang),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: onRefresh,
            ),
          ],
        ),

        // ── قیمت‌های لحظه‌ای ───────────────────────────────────
        SliverToBoxAdapter(
          child: PriceTickerWidget(lang: lang),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // ── لیست آلرت‌ها ───────────────────────────────────────
        loading
            ? const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()))
            : alerts.isEmpty
                ? SliverFillRemaining(
                    child: _EmptyState(
                      icon: Icons.notifications_none_rounded,
                      text: AppStrings.t(AppStrings.noActiveAlerts, lang),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => Slidable(
                        key: ValueKey(alerts[i].id),
                        endActionPane: ActionPane(
                          motion: const BehindMotion(),
                          extentRatio: 0.25,
                          children: [
                            SlidableAction(
                              onPressed: (_) => onDelete(alerts[i].id),
                              backgroundColor: AppTheme.red,
                              foregroundColor: Colors.white,
                              icon: Icons.delete_rounded,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ],
                        ),
                        child: AlertCard(
                          alert: alerts[i],
                          lang: lang,
                        ).animate().fadeIn(
                            duration: 300.ms,
                            delay: Duration(milliseconds: i * 60)),
                      ),
                      childCount: alerts.length,
                    ),
                  ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
    required this.alerts,
    required this.loading,
    required this.lang,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: AppTheme.background,
          title: Text(
            AppStrings.t(AppStrings.triggered, lang),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh_rounded), onPressed: onRefresh),
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
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => AlertCard(
                        alert: alerts[i],
                        lang: lang,
                        isTriggered: true,
                      ).animate().fadeIn(
                          duration: 300.ms,
                          delay: Duration(milliseconds: i * 60)),
                      childCount: alerts.length,
                    ),
                  ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
    required this.lang,
    required this.username,
    required this.onLogout,
    required this.onChangeLang,
  });

  @override
  Widget build(BuildContext context) {
    final isRtl = lang == 'fa';
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppTheme.background,
            title: Text(lang == 'fa' ? 'پروفایل' : 'Profile',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 24),

                // آواتار
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, Color(0xFF9C27B0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.person_rounded,
                      size: 40, color: Colors.white),
                ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),

                const SizedBox(height: 12),
                if (username != null)
                  Text(username!,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),

                // آیتم‌های تنظیمات
                _SettingItem(
                  icon: Icons.language_rounded,
                  title: AppStrings.t(AppStrings.selectLanguage, lang),
                  onTap: onChangeLang,
                ),
                _SettingItem(
                  icon: Icons.logout_rounded,
                  title: AppStrings.t(AppStrings.logout, lang),
                  color: AppTheme.red,
                  onTap: onLogout,
                ),
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
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Material(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: c.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: c, size: 20),
              ),
              const SizedBox(width: 14),
              Text(title,
                  style: TextStyle(
                      color: c, fontSize: 15, fontWeight: FontWeight.w500)),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: AppTheme.textSecond),
            ]),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

// ── Header Widget ─────────────────────────────────────────────────────────────

class _HeaderWidget extends StatelessWidget {
  final String lang;
  const _HeaderWidget({required this.lang});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<AlertProvider>();
    final isRtl = lang == 'fa';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A35), AppTheme.background],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 16),
      child: Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    lang == 'fa'
                        ? 'سلام${auth.username != null ? '، ${auth.username}' : ''} 👋'
                        : 'Hello${auth.username != null ? ', ${auth.username}' : ''} 👋',
                    style: const TextStyle(
                      color: AppTheme.textSecond,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lang == 'fa' ? 'آلرت‌های فعال' : 'Active Alerts',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // شمارنده
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, Color(0xFF9C27B0)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                '${provider.activeAlerts.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
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
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border),
            ),
            child: Icon(icon, size: 36, color: AppTheme.textSecond),
          ),
          const SizedBox(height: 16),
          Text(text,
              style: const TextStyle(
                  color: AppTheme.textSecond, fontSize: 15)),
        ],
      )
          .animate()
          .fadeIn(duration: 400.ms)
          .slideY(begin: 0.2, end: 0, duration: 400.ms),
    );
  }
}
