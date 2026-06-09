import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/alert_provider.dart';
import '../widgets/alert_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _loadData() {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;
    context.read<AlertProvider>().loadAlerts(userId, includeTriggered: true);
  }

  Future<void> _delete(int alertId) async {
    final userId = context.read<AuthProvider>().userId!;
    await context.read<AlertProvider>().deleteAlert(alertId, userId);
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
        appBar: AppBar(
          title: Column(children: [
            Text(s(AppStrings.myAlerts, lang)),
            if (auth.username != null)
              Text(auth.username!,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecond)),
          ]),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'logout') {
                  await auth.logout();
                  if (mounted) context.go('/login');
                } else if (v == 'lang') {
                  context.go('/language');
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'lang',
                  child: Row(children: [
                    const Icon(Icons.language, size: 18),
                    const SizedBox(width: 8),
                    Text(s(AppStrings.selectLanguage, lang)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(children: [
                    const Icon(Icons.logout, size: 18),
                    const SizedBox(width: 8),
                    Text(s(AppStrings.logout, lang)),
                  ]),
                ),
              ],
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecond,
            tabs: [
              Tab(text: '${s(AppStrings.active, lang)} (${provider.activeAlerts.length})'),
              Tab(text: '${s(AppStrings.triggered, lang)} (${provider.triggeredAlerts.length})'),
            ],
          ),
        ),

        body: provider.status == AlertStatus.loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabs,
                children: [
                  _buildList(
                    alerts: provider.activeAlerts,
                    emptyText: s(AppStrings.noActiveAlerts, lang),
                    emptyIcon: Icons.notifications_none,
                    showDelete: true,
                    lang: lang,
                  ),
                  _buildList(
                    alerts: provider.triggeredAlerts,
                    emptyText: s(AppStrings.noTriggeredAlerts, lang),
                    emptyIcon: Icons.check_circle_outline,
                    showDelete: false,
                    lang: lang,
                  ),
                ],
              ),

        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/add-alert'),
          icon: const Icon(Icons.add),
          label: Text(s(AppStrings.newAlert, lang)),
        ),
      ),
    );
  }

  Widget _buildList({
    required List alerts,
    required String emptyText,
    required IconData emptyIcon,
    required bool showDelete,
    required String lang,
  }) {
    if (alerts.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(emptyIcon, size: 64, color: AppTheme.textSecond),
          const SizedBox(height: 12),
          Text(emptyText,
              style: const TextStyle(color: AppTheme.textSecond)),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: alerts.length,
        itemBuilder: (_, i) => AlertCard(
          alert: alerts[i],
          lang: lang,
          onDelete: showDelete ? () => _delete(alerts[i].id) : null,
        ),
      ),
    );
  }
}
