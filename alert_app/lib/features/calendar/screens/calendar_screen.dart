import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/calendar_provider.dart';
import '../../../core/models/calendar_event_model.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_theme.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CalendarProvider>().load(week: 'thisweek');
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CalendarProvider>();
    final lang     = context.watch<LocaleProvider>().lang;
    final isRtl    = lang == 'fa';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.bg(context),
        appBar: AppBar(
          backgroundColor: AppTheme.bg(context),
          title: Text(
            lang == 'fa' ? 'تقویم اقتصادی' : 'Economic Calendar',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
          ),
          actions: [
            // فیلتر impact
            PopupMenuButton<String?>(
              icon: Icon(Icons.filter_list_rounded,
                  color: provider.filterImpact != null
                      ? AppTheme.primary
                      : AppTheme.textSec(context),
                  size: 20.sp),
              onSelected: (v) => provider.setImpactFilter(v),
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: null,
                    child: Text(lang == 'fa' ? 'همه' : 'All')),
                const PopupMenuItem(value: 'high',   child: Text('🔴 High')),
                const PopupMenuItem(value: 'medium', child: Text('🟠 Medium')),
                const PopupMenuItem(value: 'low',    child: Text('🟡 Low')),
              ],
            ),
            IconButton(
              icon: Icon(Icons.refresh_rounded, size: 20.sp),
              onPressed: () =>
                  provider.load(week: provider.week),
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            onTap: (i) => provider.load(
                week: i == 0 ? 'thisweek' : 'nextweek'),
            tabs: [
              Tab(text: lang == 'fa' ? 'این هفته' : 'This Week'),
              Tab(text: lang == 'fa' ? 'هفته آینده' : 'Next Week'),
            ],
          ),
        ),
        body: provider.status == CalendarStatus.loading
            ? const Center(child: CircularProgressIndicator())
            : provider.status == CalendarStatus.error
                ? _ErrorWidget(
                    error: provider.error ?? '',
                    onRetry: () => provider.load(week: provider.week),
                  )
                : provider.events.isEmpty
                    ? Center(
                        child: Text(
                          lang == 'fa'
                              ? 'رویدادی یافت نشد'
                              : 'No events found',
                          style: TextStyle(
                              color: AppTheme.textSec(context),
                              fontSize: 13.sp),
                        ),
                      )
                    : _EventList(events: provider.events, lang: lang),
      ),
    );
  }
}

// ── لیست رویدادها ─────────────────────────────────────────────────────────────

class _EventList extends StatelessWidget {
  final List<CalendarEventModel> events;
  final String lang;

  const _EventList({required this.events, required this.lang});

  @override
  Widget build(BuildContext context) {
    // گروه‌بندی بر اساس تاریخ
    final Map<String, List<CalendarEventModel>> grouped = {};
    for (final e in events) {
      grouped.putIfAbsent(e.date, () => []).add(e);
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      itemCount: grouped.length,
      itemBuilder: (_, i) {
        final date   = grouped.keys.elementAt(i);
        final dayEvs = grouped[date]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── هدر تاریخ ──────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 6.h),
              child: Row(children: [
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    date,
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                    child: Divider(
                        color: AppTheme.divider(context), height: 1)),
              ]),
            ),
            // ── رویدادها ───────────────────────────────────────────
            ...dayEvs.asMap().entries.map((entry) => _EventCard(
                  event: entry.value,
                  lang: lang,
                ).animate().fadeIn(
                    duration: 200.ms,
                    delay: Duration(milliseconds: entry.key * 40))),
          ],
        );
      },
    );
  }
}

// ── کارت رویداد ───────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final CalendarEventModel event;
  final String lang;

  const _EventCard({required this.event, required this.lang});

  Color _impactColor(BuildContext context) {
    switch (event.impact) {
      case 'high':    return AppTheme.red;
      case 'medium':  return AppTheme.orange;
      case 'low':     return const Color(0xFFFFEB3B);
      case 'holiday': return AppTheme.blue;
      default:        return AppTheme.textSec(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final impactColor = _impactColor(context);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // ── نوار impact ─────────────────────────────────────────
            Container(
              width: 4.w,
              decoration: BoxDecoration(
                color: impactColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14.r),
                  bottomLeft: Radius.circular(14.r),
                ),
              ),
            ),

            // ── محتوا ───────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(10.w),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // زمان + ارز
                    SizedBox(
                      width: 50.w,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            event.time,
                            style: TextStyle(
                              color: AppTheme.textSec(context),
                              fontSize: 10.sp,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: impactColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              event.currency,
                              style: TextStyle(
                                color: impactColor,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 10.w),

                    // عنوان + مقادیر
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: TextStyle(
                              color: AppTheme.text(context),
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (event.forecast.isNotEmpty ||
                              event.previous.isNotEmpty ||
                              event.actual.isNotEmpty) ...[
                            SizedBox(height: 6.h),
                            Row(children: [
                              if (event.actual.isNotEmpty)
                                _ValueChip(
                                  label: lang == 'fa' ? 'واقعی' : 'Actual',
                                  value: event.actual,
                                  color: AppTheme.green,
                                ),
                              if (event.forecast.isNotEmpty) ...[
                                SizedBox(width: 6.w),
                                _ValueChip(
                                  label: lang == 'fa' ? 'پیش‌بینی' : 'Forecast',
                                  value: event.forecast,
                                  color: AppTheme.blue,
                                ),
                              ],
                              if (event.previous.isNotEmpty) ...[
                                SizedBox(width: 6.w),
                                _ValueChip(
                                  label: lang == 'fa' ? 'قبلی' : 'Previous',
                                  value: event.previous,
                                  color: AppTheme.textSec(context),
                                ),
                              ],
                            ]),
                          ],
                        ],
                      ),
                    ),

                    // آیکون impact
                    SizedBox(width: 6.w),
                    _ImpactDot(impact: event.impact, color: impactColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ValueChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: AppTheme.textSec(context), fontSize: 9.sp)),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 11.sp,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _ImpactDot extends StatelessWidget {
  final String impact;
  final Color color;

  const _ImpactDot({required this.impact, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10.w,
      height: 10.w,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 4.r,
              spreadRadius: 1)
        ],
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorWidget({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              color: AppTheme.red, size: 40.sp),
          SizedBox(height: 10.h),
          Text('خطا در دریافت تقویم',
              style: TextStyle(
                  color: AppTheme.textSec(context), fontSize: 13.sp)),
          SizedBox(height: 14.h),
          ElevatedButton(onPressed: onRetry, child: const Text('تلاش مجدد')),
        ],
      ),
    );
  }
}
