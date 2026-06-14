import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/widgets/shimmer_widgets.dart';
import '../providers/alert_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/models/alert_model.dart';

class AlertHistoryScreen extends StatefulWidget {
  const AlertHistoryScreen({super.key});

  @override
  State<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    if (auth.userId != null) {
      await context.read<AlertProvider>().loadAlerts(
          auth.userId!, includeTriggered: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final lang   = context.watch<LocaleProvider>().lang;
    final isRtl  = lang == 'fa';
    final isDark = context.watch<ThemeProvider>().isDark;
    final all    = context.watch<AlertProvider>().alerts;
    final hist   = all.where((a) => a.triggered).toList()
      ..sort((a, b) => b.triggeredAt!.compareTo(a.triggeredAt!));

    // Group by date
    final grouped = <String, List<AlertModel>>{};
    for (final a in hist) {
      final date = a.triggeredAt?.substring(0, 10) ?? '—';
      grouped.putIfAbsent(date, () => []).add(a);
    }

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
          elevation: 0,
          title: Text(
            lang == 'fa' ? 'تاریخچه آلرت‌ها' : 'Alert History',
            style: TextStyle(
              fontSize: 18.sp, fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          actions: [
            if (hist.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(right: 12.w),
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C853).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      '${hist.length} ${lang == 'fa' ? 'آلرت' : 'alerts'}',
                      style: TextStyle(
                        fontSize: 12.sp, fontWeight: FontWeight.w600,
                        color: const Color(0xFF00C853),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          color: AppTheme.primary,
          child: _loading
              ? const ShimmerList(count: 5)
              : hist.isEmpty
                  ? _EmptyHistory(lang: lang, isDark: isDark)
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      itemCount: grouped.keys.length,
                      itemBuilder: (_, i) {
                        final date  = grouped.keys.elementAt(i);
                        final items = grouped[date]!;
                        return _DateGroup(
                          date: date,
                          items: items,
                          isDark: isDark,
                          lang: lang,
                          groupIndex: i,
                        );
                      },
                    ),
        ),
      ),
    );
  }
}

// ── Date group ────────────────────────────────────────────────────────────────

class _DateGroup extends StatelessWidget {
  const _DateGroup({
    required this.date,
    required this.items,
    required this.isDark,
    required this.lang,
    required this.groupIndex,
  });

  final String date;
  final List<AlertModel> items;
  final bool isDark;
  final String lang;
  final int groupIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 6.h),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  date,
                  style: TextStyle(
                    fontSize: 11.sp, fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                    fontFamily: 'TexGyreAdventor',
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                '${items.length} ${lang == 'fa' ? 'آلرت' : 'alerts'}',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: (groupIndex * 50).ms),
        // Alert tiles
        ...items.asMap().entries.map((e) => _HistoryTile(
          alert: e.value,
          isDark: isDark,
          lang: lang,
          itemIndex: e.key,
          groupIndex: groupIndex,
        )),
      ],
    );
  }
}

// ── History tile ──────────────────────────────────────────────────────────────

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.alert,
    required this.isDark,
    required this.lang,
    required this.itemIndex,
    required this.groupIndex,
  });

  final AlertModel alert;
  final bool isDark;
  final String lang;
  final int itemIndex;
  final int groupIndex;

  @override
  Widget build(BuildContext context) {
    final isUp    = alert.alertType == 'above';
    final color   = isUp ? const Color(0xFF00C853) : const Color(0xFFFF1744);
    final timeStr = alert.triggeredAt?.substring(11, 16) ?? '';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
          blurRadius: 5, offset: const Offset(0, 2),
        )],
      ),
      child: Padding(
        padding: EdgeInsets.all(14.r),
        child: Row(
          children: [
            // Direction indicator
            Container(
              width: 38.w, height: 38.h,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12), shape: BoxShape.circle,
              ),
              child: Icon(
                isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                color: color, size: 18.sp,
              ),
            ),
            SizedBox(width: 12.w),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        alert.symbol,
                        style: TextStyle(
                          fontSize: 15.sp, fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                          fontFamily: 'TexGyreAdventor',
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          '#${alert.id}',
                          style: TextStyle(
                            fontSize: 9.sp,
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontFamily: 'TexGyreAdventor',
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    '${lang == 'fa' ? 'هدف: ' : 'Target: '}'
                    '${alert.targetPrice.toStringAsFixed(alert.targetPrice >= 1000 ? 2 : 5)}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            // Time + badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    lang == 'fa' ? '✅ رسید' : '✅ Hit',
                    style: TextStyle(
                      fontSize: 10.sp, fontWeight: FontWeight.w600,
                      color: const Color(0xFF00C853),
                    ),
                  ),
                ),
                if (timeStr.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontFamily: 'TexGyreAdventor',
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: ((groupIndex * 3 + itemIndex) * 40).ms)
        .slideX(begin: 0.05, end: 0);
  }
}

// ── Empty ─────────────────────────────────────────────────────────────────────

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.lang, required this.isDark});
  final String lang;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🏆', style: TextStyle(fontSize: 52.sp))
              .animate().scale(duration: 400.ms),
          SizedBox(height: 16.h),
          Text(
            lang == 'fa' ? 'هنوز هیچ آلرتی تریگر نشده' : 'No triggered alerts yet',
            style: TextStyle(
              fontSize: 15.sp, fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            lang == 'fa'
                ? 'وقتی قیمت به هدفت برسه اینجا نمایش داده میشه'
                : 'Alerts will appear here when prices hit their targets',
            style: TextStyle(
              fontSize: 12.sp,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
