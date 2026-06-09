import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/alert_provider.dart';
import '../widgets/alert_card.dart';
import '../../auth/providers/auth_provider.dart';
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
    context.read<AlertProvider>().loadStats();
  }

  Future<void> _delete(int alertId) async {
    final userId = context.read<AuthProvider>().userId!;
    final ok = await context.read<AlertProvider>().deleteAlert(alertId, userId);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<AlertProvider>().error ?? 'خطا'),
          backgroundColor: AppTheme.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final provider = context.watch<AlertProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('آلرت‌های من'),
            if (auth.username != null)
              Text(auth.username!,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecond)),
          ],
        ),
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
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout, size: 18),
                  SizedBox(width: 8),
                  Text('خروج'),
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
            Tab(text: 'فعال (${provider.activeAlerts.length})'),
            Tab(text: 'فعال‌شده (${provider.triggeredAlerts.length})'),
          ],
        ),
      ),

      body: provider.status == AlertStatus.loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                // تب آلرت‌های فعال
                _buildList(
                  alerts: provider.activeAlerts,
                  emptyText: 'هیچ آلرت فعالی ندارید',
                  emptyIcon: Icons.notifications_none,
                  showDelete: true,
                ),

                // تب آلرت‌های فعال‌شده
                _buildList(
                  alerts: provider.triggeredAlerts,
                  emptyText: 'هنوز هیچ آلرتی فعال نشده',
                  emptyIcon: Icons.check_circle_outline,
                  showDelete: false,
                ),
              ],
            ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-alert'),
        icon: const Icon(Icons.add),
        label: const Text('آلرت جدید'),
      ),
    );
  }

  Widget _buildList({
    required List alerts,
    required String emptyText,
    required IconData emptyIcon,
    required bool showDelete,
  }) {
    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon, size: 64, color: AppTheme.textSecond),
            const SizedBox(height: 12),
            Text(emptyText,
                style: const TextStyle(color: AppTheme.textSecond)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: alerts.length,
        itemBuilder: (_, i) => AlertCard(
          alert: alerts[i],
          onDelete: showDelete ? () => _delete(alerts[i].id) : null,
        ),
      ),
    );
  }
}
