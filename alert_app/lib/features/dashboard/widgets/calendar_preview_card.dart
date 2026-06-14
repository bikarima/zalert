import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../calendar/providers/calendar_provider.dart';

class CalendarPreviewCard extends StatelessWidget {
  const CalendarPreviewCard({super.key, required this.lang, required this.isDark});
  final String lang;
  final bool   isDark;

  static const _impactColor = {
    'high':         Color(0xFFFF1744),
    'medium':       Color(0xFFFF9100),
    'low':          Color(0xFF00C853),
    'holiday':      Color(0xFF7C4DFF),
    'non_economic': Color(0xFF90A4AE),
  };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CalendarProvider>();
    final events   = provider.events.where((e) {
      final today = DateTime.now();
      return e.date == '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';
    }).toList();
    final high = events.where((e) => e.impact == 'high').toList();
    final show = high.isNotEmpty ? high.take(4).toList() : events.take(3).toList();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 8, offset: const Offset(0, 2),
          )],
        ),
        child: show.isEmpty
            ? Padding(
                padding: EdgeInsets.all(16.r),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: const Color(0xFF00C853), size: 18.sp),
                    SizedBox(width: 8.w),
                    Text(
                      lang == 'fa' ? 'امروز رویداد مهمی نداریم ✅' : 'No high-impact events today ✅',
                      style: TextStyle(fontSize: 13.sp,
                          color: isDark ? Colors.white70 : Colors.black54),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.all(12.r),
                itemCount: show.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                ),
                itemBuilder: (_, i) {
                  final e = show[i];
                  final color = _impactColor[e.impact] ?? Colors.grey;
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Row(
                      children: [
                        Container(
                          width: 4.w, height: 36.h,
                          decoration: BoxDecoration(
                            color: color, borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.title,
                                style: TextStyle(
                                  fontSize: 12.sp, fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${e.currency}  •  ${e.time}',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (e.forecast.isNotEmpty || e.previous.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (e.forecast.isNotEmpty)
                                Text(e.forecast,
                                    style: TextStyle(fontSize: 10.sp, color: color,
                                        fontWeight: FontWeight.w600)),
                              if (e.previous.isNotEmpty)
                                Text(lang == 'fa' ? 'قبلی: ${e.previous}' : 'prev: ${e.previous}',
                                    style: TextStyle(fontSize: 9.sp,
                                        color: isDark ? Colors.white38 : Colors.black38)),
                            ],
                          ),
                      ],
                    ),
                  ).animate().fadeIn(delay: (i * 50).ms);
                },
              ),
      ),
    );
  }
}
