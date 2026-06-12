import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/models/alert_model.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';

class AlertCard extends StatelessWidget {
  final AlertModel alert;
  final String lang;
  final VoidCallback? onDelete;
  final bool isTriggered;

  const AlertCard({
    super.key,
    required this.alert,
    required this.lang,
    this.onDelete,
    this.isTriggered = false,
  });

  @override
  Widget build(BuildContext context) {
    final isAbove  = alert.isAbove;
    final dirColor = isAbove ? AppTheme.green : AppTheme.red;
    final dirIcon  = isAbove ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final cardBg   = AppTheme.card(context);
    final borderC  = isTriggered
        ? AppTheme.green.withOpacity(0.4)
        : AppTheme.border(context);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: borderC),
        boxShadow: isTriggered
            ? [BoxShadow(
                color: AppTheme.green.withOpacity(0.08),
                blurRadius: 10.r, offset: const Offset(0, 4))]
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Row(
          children: [
            // آیکون جهت
            Container(
              width: 42.w, height: 42.w,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [dirColor.withOpacity(0.2), dirColor.withOpacity(0.05)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: dirColor.withOpacity(0.3)),
              ),
              child: Icon(dirIcon, color: dirColor, size: 18.sp),
            ),
            SizedBox(width: 10.w),

            // اطلاعات
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(alert.symbol,
                        style: TextStyle(
                            color: AppTheme.text(context),
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5)),
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: dirColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: dirColor.withOpacity(0.3)),
                      ),
                      child: Text(alert.direction,
                          style: TextStyle(color: dirColor,
                              fontSize: 9.sp, fontWeight: FontWeight.w600)),
                    ),
                    if (isTriggered) ...[
                      SizedBox(width: 4.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: AppTheme.green.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Text('✓ Hit',
                            style: TextStyle(color: AppTheme.green,
                                fontSize: 9.sp, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ]),
                  SizedBox(height: 6.h),
                  Row(children: [
                    Icon(Icons.flag_rounded, size: 11.sp, color: AppTheme.primary),
                    SizedBox(width: 3.w),
                    Text(
                      '${AppStrings.t(AppStrings.target, lang)}: ${_fmt(alert.targetPrice)}',
                      style: TextStyle(
                          color: AppTheme.primary.withOpacity(0.9),
                          fontSize: 11.sp, fontWeight: FontWeight.w500),
                    ),
                  ]),
                  SizedBox(height: 2.h),
                  Text(
                    isTriggered && alert.triggeredAt != null
                        ? alert.triggeredAt! : alert.createdAt,
                    style: TextStyle(
                        color: AppTheme.textHint(context), fontSize: 10.sp),
                  ),
                ],
              ),
            ),

            if (onDelete != null)
              IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    color: AppTheme.textSec(context), size: 18.sp),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32.w, minHeight: 32.h),
              ),
          ],
        ),
      ),
    );
  }

  String _fmt(double price) {
    if (price >= 1000) return price.toStringAsFixed(2);
    if (price >= 10)   return price.toStringAsFixed(4);
    return price.toStringAsFixed(5);
  }
}
