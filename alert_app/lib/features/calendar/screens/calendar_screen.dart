import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/calendar_provider.dart';
import '../models/calendar_filter.dart';
import '../widgets/calendar_filter_sheet.dart';
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
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CalendarProvider>().load(week: 'thisweek');
    });
    // هر ثانیه UI رو آپدیت کن تا countdown زنده باشه
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _ticker?.cancel();
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
            // دکمه فیلتر
            Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  icon: Icon(Icons.filter_list_rounded,
                      color: !provider.filter.isDefault
                          ? AppTheme.primary
                          : AppTheme.textSec(context),
                      size: 22.sp),
                  onPressed: () async {
                    final result = await showModalBottomSheet<CalendarFilter>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => CalendarFilterSheet(
                        initial: provider.filter,
                        lang: lang,
                      ),
                    );
                    if (result != null) {
                      provider.applyFilter(result);
                    }
                  },
                ),
                if (!provider.filter.isDefault)
                  Positioned(
                    top: 8.h, right: 8.w,
                    child: Container(
                      width: 8.w, height: 8.w,
                      decoration: const BoxDecoration(
                          color: AppTheme.red, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: Icon(Icons.refresh_rounded, size: 20.sp),
              onPressed: () => provider.load(week: provider.week),
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            onTap: (i) => provider.load(week: i == 0 ? 'thisweek' : 'nextweek'),
            tabs: [
              Tab(text: lang == 'fa' ? 'این هفته' : 'This Week'),
              Tab(text: lang == 'fa' ? 'هفته آینده' : 'Next Week'),
            ],
          ),
        ),
        body: Column(
          children: [
            // ── Next High Impact Banner ──────────────────────────────
            if (provider.nextHighImpact != null)
              _NextEventBanner(
                  event: provider.nextHighImpact!, lang: lang),

            // ── لیست ────────────────────────────────────────────────
            Expanded(
              child: provider.status == CalendarStatus.loading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.status == CalendarStatus.error
                      ? _ErrorWidget(
                          error: provider.error ?? '',
                          onRetry: () => provider.load(week: provider.week))
                      : provider.events.isEmpty
                          ? Center(child: Text(
                              lang == 'fa' ? 'رویدادی یافت نشد' : 'No events found',
                              style: TextStyle(
                                  color: AppTheme.textSec(context), fontSize: 13.sp)))
                          : _EventList(events: provider.events, lang: lang),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Next Event Banner با Progress Bar ────────────────────────────────────────

class _NextEventBanner extends StatelessWidget {
  final CalendarEventModel event;
  final String lang;

  const _NextEventBanner({required this.event, required this.lang});

  @override
  Widget build(BuildContext context) {
    final remaining = event.timeUntil;
    if (remaining == null) return const SizedBox.shrink();

    final totalMins  = remaining.inMinutes;
    final hours      = remaining.inHours;
    final mins       = remaining.inMinutes % 60;
    final secs       = remaining.inSeconds % 60;

    // progress — نمایش 2 ساعت به عنوان کل بازه
    const maxMins = 120.0;
    final progress = (1.0 - (totalMins / maxMins)).clamp(0.0, 1.0);

    final timeStr = hours > 0
        ? '$hours:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}'
        : '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    final isUrgent = totalMins <= 10;

    return Container(
      margin: EdgeInsets.all(12.w),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUrgent
              ? [AppTheme.red.withOpacity(0.2), AppTheme.red.withOpacity(0.05)]
              : [AppTheme.red.withOpacity(0.12), AppTheme.red.withOpacity(0.03)],
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isUrgent
              ? AppTheme.red.withOpacity(0.6)
              : AppTheme.red.withOpacity(0.3),
          width: isUrgent ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: AppTheme.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text('🔴 HIGH',
                  style: TextStyle(color: AppTheme.red,
                      fontSize: 10.sp, fontWeight: FontWeight.bold)),
            ),
            SizedBox(width: 8.w),
            Text(event.currency,
                style: TextStyle(color: AppTheme.text(context),
                    fontSize: 12.sp, fontWeight: FontWeight.bold)),
            const Spacer(),
            // countdown
            AnimatedContainer(
              duration: 300.ms,
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: isUrgent
                    ? AppTheme.red.withOpacity(0.2)
                    : AppTheme.surface(context),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                    color: isUrgent ? AppTheme.red : AppTheme.border(context)),
              ),
              child: Text(
                timeStr,
                style: TextStyle(
                  color: isUrgent ? AppTheme.red : AppTheme.text(context),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ]),
          SizedBox(height: 6.h),
          Text(event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppTheme.textSec(context), fontSize: 11.sp)),
          SizedBox(height: 8.h),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5.h,
              backgroundColor: AppTheme.border(context),
              valueColor: AlwaysStoppedAnimation<Color>(
                isUrgent ? AppTheme.red : AppTheme.orange),
            ),
          ),
          SizedBox(height: 4.h),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(lang == 'fa' ? 'الان' : 'Now',
                style: TextStyle(color: AppTheme.textSec(context), fontSize: 9.sp)),
            Text(lang == 'fa' ? 'زمان خبر: ${event.time}' : 'Event: ${event.time}',
                style: TextStyle(color: AppTheme.red, fontSize: 9.sp,
                    fontWeight: FontWeight.w600)),
          ]),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── لیست رویدادها ─────────────────────────────────────────────────────────────

class _EventList extends StatelessWidget {
  final List<CalendarEventModel> events;
  final String lang;
  const _EventList({required this.events, required this.lang});

  @override
  Widget build(BuildContext context) {
    final Map<String, List<CalendarEventModel>> grouped = {};
    for (final e in events) {
      grouped.putIfAbsent(e.date, () => []).add(e);
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: 16.h),
      itemCount: grouped.length,
      itemBuilder: (_, i) {
        final date   = grouped.keys.elementAt(i);
        final dayEvs = grouped[date]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 4.h),
              child: Row(children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(date,
                      style: TextStyle(color: AppTheme.primary,
                          fontSize: 11.sp, fontWeight: FontWeight.bold)),
                ),
                SizedBox(width: 8.w),
                Expanded(child: Divider(color: AppTheme.divider(context), height: 1)),
              ]),
            ),
            ...dayEvs.asMap().entries.map((entry) =>
                _EventCard(event: entry.value, lang: lang)
                    .animate()
                    .fadeIn(duration: 200.ms,
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
      case 'low':     return const Color(0xFFFFD600);
      case 'holiday': return AppTheme.blue;
      default:        return AppTheme.textSec(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final impactColor = _impactColor(context);
    final remaining   = event.timeUntil;
    final isUpcoming  = remaining != null && remaining.inMinutes <= 60;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isUpcoming && event.isHighImpact
              ? impactColor.withOpacity(0.4)
              : AppTheme.border(context),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // نوار impact
            Container(
              width: 4.w,
              decoration: BoxDecoration(
                color: impactColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12.r),
                  bottomLeft: Radius.circular(12.r),
                ),
              ),
            ),

            // محتوا
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(10.w),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // زمان + ارز
                    SizedBox(
                      width: 52.w,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(event.time,
                              style: TextStyle(
                                  color: AppTheme.textSec(context),
                                  fontSize: 10.sp)),
                          SizedBox(height: 4.h),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 5.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: impactColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(event.currency,
                                style: TextStyle(
                                    color: impactColor,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),

                    // عنوان + مقادیر
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: AppTheme.text(context),
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600)),
                          if (event.forecast.isNotEmpty ||
                              event.previous.isNotEmpty ||
                              event.actual.isNotEmpty) ...[
                            SizedBox(height: 5.h),
                            Row(children: [
                              if (event.actual.isNotEmpty)
                                _ValueChip(label: lang == 'fa' ? 'واقعی' : 'Actual',
                                    value: event.actual, color: AppTheme.green),
                              if (event.forecast.isNotEmpty) ...[
                                SizedBox(width: 8.w),
                                _ValueChip(label: lang == 'fa' ? 'پیش‌بینی' : 'Forecast',
                                    value: event.forecast, color: AppTheme.blue),
                              ],
                              if (event.previous.isNotEmpty) ...[
                                SizedBox(width: 8.w),
                                _ValueChip(label: lang == 'fa' ? 'قبلی' : 'Previous',
                                    value: event.previous,
                                    color: AppTheme.textSec(context)),
                              ],
                            ]),
                          ],
                        ],
                      ),
                    ),

                    // dot + countdown کوچک
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 9.w, height: 9.w,
                          decoration: BoxDecoration(
                            color: impactColor,
                            shape: BoxShape.circle,
                            boxShadow: event.isHighImpact ? [BoxShadow(
                              color: impactColor.withOpacity(0.5),
                              blurRadius: 4.r, spreadRadius: 1,
                            )] : null,
                          ),
                        ),
                        if (remaining != null && remaining.inHours < 2) ...[
                          SizedBox(height: 4.h),
                          Text(
                            remaining.inMinutes < 60
                                ? '${remaining.inMinutes}m'
                                : '${remaining.inHours}h',
                            style: TextStyle(
                                color: impactColor,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
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
  const _ValueChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: AppTheme.textSec(context), fontSize: 9.sp)),
      Text(value, style: TextStyle(color: color, fontSize: 11.sp,
          fontWeight: FontWeight.bold)),
    ]);
  }
}

class _ErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorWidget({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.error_outline_rounded, color: AppTheme.red, size: 36.sp),
      SizedBox(height: 10.h),
      Text('خطا در دریافت تقویم',
          style: TextStyle(color: AppTheme.textSec(context), fontSize: 13.sp)),
      SizedBox(height: 12.h),
      ElevatedButton(onPressed: onRetry, child: const Text('تلاش مجدد')),
    ]));
  }
}
