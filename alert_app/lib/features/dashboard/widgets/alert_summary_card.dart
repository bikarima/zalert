import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../alerts/providers/alert_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/l10n/locale_provider.dart';

class AlertSummaryCard extends StatelessWidget {
  const AlertSummaryCard({
    super.key,
    required this.lang,
    required this.isDark,
    required this.onAddAlert,
    required this.onViewAll,
  });

  final String lang;
  final bool   isDark;
  final VoidCallback onAddAlert;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<AlertProvider>().alerts;
    final active  = alerts.where((a) => !a.triggered).toList();
    final recent  = active.take(3).toList();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 8, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 8.h),
              child: Row(
                children: [
                  _StatPill(
                    count: active.length,
                    label: lang == 'fa' ? 'فعال' : 'Active',
                    color: AppTheme.primary,
                  ),
                  SizedBox(width: 8.w),
                  _StatPill(
                    count: alerts.where((a) => a.triggered).length,
                    label: lang == 'fa' ? 'تریگر شده' : 'Triggered',
                    color: const Color(0xFF00C853),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onAddAlert,
                    icon: Icon(Icons.add_circle_outline,
                        color: AppTheme.primary, size: 22.sp),
                    tooltip: lang == 'fa' ? 'آلرت جدید' : 'New alert',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            if (recent.isEmpty) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
                child: Text(
                  lang == 'fa'
                      ? 'هنوز آلرتی نداری. با + اضافه کن!'
                      : 'No alerts yet. Tap + to add one!',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
            ] else ...[
              // ── Recent alerts ──────────────────────────────────
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 4.h),
                itemCount: recent.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                ),
                itemBuilder: (_, i) {
                  final a    = recent[i];
                  final isUp = a.alertType == 'above';
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Row(
                      children: [
                        Container(
                          width: 32.w, height: 32.h,
                          decoration: BoxDecoration(
                            color: (isUp
                                ? const Color(0xFF00C853)
                                : const Color(0xFFFF1744)).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isUp ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 14.sp,
                            color: isUp
                                ? const Color(0xFF00C853)
                                : const Color(0xFFFF1744),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.symbol,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontFamily: 'TexGyreAdventor',
                                ),
                              ),
                              Text(
                                '${lang == 'fa' ? 'هدف: ' : 'Target: '}${a.targetPrice}',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            '#${a.id}',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'TexGyreAdventor',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: (i * 60).ms);
                },
              ),

              // ── View all button ────────────────────────────────
              if (active.length > 3)
                InkWell(
                  onTap: onViewAll,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 12.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          lang == 'fa'
                              ? 'مشاهده همه ${active.length} آلرت'
                              : 'View all ${active.length} alerts',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(Icons.chevron_right, size: 14.sp,
                            color: AppTheme.primary),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(height: 8.h),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.count, required this.label, required this.color});
  final int count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14.sp, fontWeight: FontWeight.bold,
              color: color, fontFamily: 'TexGyreAdventor',
            ),
          ),
          SizedBox(width: 4.w),
          Text(label, style: TextStyle(fontSize: 10.sp, color: color)),
        ],
      ),
    );
  }
}
