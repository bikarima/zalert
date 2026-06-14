import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/calendar_provider.dart';
import '../../../core/models/calendar_event_model.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/shimmer_widgets.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Timer? _ticker;
  String _activeFilter = 'all'; // all / high / medium / low

  static const _impactColors = {
    'high':         Color(0xFFFF5252),
    'medium':       Color(0xFFFFAB40),
    'low':          Color(0xFF00E676),
    'holiday':      Color(0xFF7C4DFF),
    'non_economic': Color(0xFF607D8B),
  };

  static const _impactLabels = {
    'high':         ('پرخطر', 'High'),
    'medium':       ('متوسط', 'Medium'),
    'low':          ('کم‌خطر', 'Low'),
  };

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CalendarProvider>().load();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  List<CalendarEventModel> _filtered(List<CalendarEventModel> all) {
    if (_activeFilter == 'all') return all;
    return all.where((e) => e.impact == _activeFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lang   = context.watch<LocaleProvider>().lang;
    final isDark = context.watch<ThemeProvider>().isDark;
    final prov   = context.watch<CalendarProvider>();
    final events = _filtered(prov.events);
    final next   = prov.nextHighImpact;

    // group by date
    final grouped = <String, List<CalendarEventModel>>{};
    for (final e in events) {
      grouped.putIfAbsent(e.date, () => []).add(e);
    }

    return Directionality(
      textDirection: lang == 'fa' ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
        body: RefreshIndicator(
          onRefresh: () => prov.load(),
          color: const Color(0xFFFF5252),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [

              // ── Header ────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 155.h,
                floating: false, pinned: true,
                backgroundColor: Colors.transparent, elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: _CalendarHeader(
                    lang: lang, next: next, isDark: isDark,
                  ),
                ),
              ),

              // ── Filter chips ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: lang == 'fa' ? 'همه' : 'All',
                        active: _activeFilter == 'all',
                        color: AppTheme.primary,
                        onTap: () => setState(() => _activeFilter = 'all'),
                      ),
                      SizedBox(width: 8.w),
                      ..._impactLabels.entries.map((e) => Padding(
                        padding: EdgeInsets.only(right: 8.w),
                        child: _FilterChip(
                          label: lang == 'fa' ? e.value.$1 : e.value.$2,
                          active: _activeFilter == e.key,
                          color: _impactColors[e.key] ?? AppTheme.primary,
                          onTap: () => setState(() => _activeFilter = e.key),
                        ),
                      )),
                    ],
                  ),
                ),
              ),

              // ── Events ───────────────────────────────────────────────
              if (prov.status == CalendarStatus.loading)
                SliverPadding(
                  padding: EdgeInsets.only(bottom: 120.h),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, __) => const ShimmerAlertTile(), childCount: 6,
                    ),
                  ),
                )
              else if (events.isEmpty)
                SliverFillRemaining(
                  child: _EmptyCalendar(lang: lang, isDark: isDark),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 120.h),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final date   = grouped.keys.elementAt(i);
                        final dayEvs = grouped[date]!;
                        return _DateSection(
                          date:   date,
                          events: dayEvs,
                          lang:   lang,
                          isDark: isDark,
                          colors: _impactColors,
                          index:  i,
                        );
                      },
                      childCount: grouped.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header with countdown ─────────────────────────────────────────────────────

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({required this.lang, required this.next, required this.isDark});
  final String lang;
  final CalendarEventModel? next;
  final bool isDark;

  String _countdown(CalendarEventModel e) {
    if (e.timeUtc.isEmpty) return '';
    try {
      final dt   = DateTime.parse(e.timeUtc).toLocal();
      final diff = dt.difference(DateTime.now());
      if (diff.isNegative) return lang == 'fa' ? 'در حال وقوع' : 'Happening now';
      final h = diff.inHours;
      final m = diff.inMinutes % 60;
      final s = diff.inSeconds % 60;
      if (h > 0) return '${h}h ${m}m';
      if (m > 0) return '${m}m ${s}s';
      return '${s}s';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFCC2244), Color(0xFFFF5252), Color(0xFFFF8A65)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                lang == 'fa' ? 'تقویم اقتصادی' : 'Economic Calendar',
                style: TextStyle(
                  fontSize: 24.sp, fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 6.h),
              if (next != null) ...[
                Row(children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.timer_outlined, size: 12.sp, color: Colors.white),
                      SizedBox(width: 4.w),
                      Text(
                        '${lang == 'fa' ? 'بعدی: ' : 'Next: '}${next!.title}',
                        style: TextStyle(fontSize: 11.sp, color: Colors.white,
                            fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ]),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      _countdown(next!),
                      style: TextStyle(
                        fontSize: 12.sp, color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'TexGyreAdventor',
                      ),
                    ),
                  ),
                ]),
              ] else
                Text(
                  lang == 'fa' ? 'رویداد High Impact ای در پیش نیست' : 'No upcoming High Impact events',
                  style: TextStyle(fontSize: 12.sp, color: Colors.white70),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Date section ──────────────────────────────────────────────────────────────

class _DateSection extends StatelessWidget {
  const _DateSection({
    required this.date, required this.events, required this.lang,
    required this.isDark, required this.colors, required this.index,
  });

  final String date;
  final List<CalendarEventModel> events;
  final String lang, isDark;
  final Map<String, Color> colors;
  final int index;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final highCount = events.where((e) => e.impact == 'high').length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          child: Row(children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: highCount > 0
                    ? const Color(0xFFFF5252).withOpacity(0.12)
                    : AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                date,
                style: TextStyle(
                  fontSize: 12.sp, fontWeight: FontWeight.bold,
                  color: highCount > 0
                      ? const Color(0xFFFF5252)
                      : AppTheme.primary,
                  fontFamily: 'TexGyreAdventor',
                ),
              ),
            ),
            if (highCount > 0) ...[
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  '$highCount 🔴',
                  style: TextStyle(fontSize: 10.sp, color: const Color(0xFFFF5252)),
                ),
              ),
            ],
          ]),
        ).animate().fadeIn(delay: (index * 40).ms),
        ...events.asMap().entries.map((e) => _EventCard(
          event:  e.value,
          lang:   lang,
          isDark: isDark,
          color:  colors[e.value.impact] ?? Colors.grey,
          index:  index * 10 + e.key,
        )),
        SizedBox(height: 4.h),
      ],
    );
  }
}

// ── Event card ────────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event, required this.lang, required this.isDark,
    required this.color, required this.index,
  });

  final CalendarEventModel event;
  final String lang;
  final bool   isDark;
  final Color  color;
  final int    index;

  @override
  Widget build(BuildContext context) {
    final hasData = event.forecast.isNotEmpty || event.previous.isNotEmpty
        || event.actual.isNotEmpty;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: EdgeInsets.all(14.r),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                // Impact bar
                Container(
                  width: 4.w, height: 46.h,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2.r),
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.4), blurRadius: 6),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: TextStyle(
                              fontSize: 13.sp, fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            event.currency,
                            style: TextStyle(
                              fontSize: 10.sp, color: color,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'TexGyreAdventor',
                            ),
                          ),
                        ),
                      ]),
                      SizedBox(height: 4.h),
                      Row(children: [
                        Icon(Icons.schedule_outlined,
                            size: 11.sp,
                            color: isDark ? Colors.white38 : Colors.black38),
                        SizedBox(width: 3.w),
                        Text(
                          event.time,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontFamily: 'TexGyreAdventor',
                          ),
                        ),
                        if (hasData) ...[
                          SizedBox(width: 12.w),
                          if (event.actual.isNotEmpty)
                            _DataPill(
                                label: lang == 'fa' ? 'واقعی' : 'Actual',
                                value: event.actual,
                                color: const Color(0xFF00E676)),
                          if (event.forecast.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(right: 6.w),
                              child: _DataPill(
                                  label: lang == 'fa' ? 'پیش‌بینی' : 'Forecast',
                                  value: event.forecast,
                                  color: AppTheme.primary),
                            ),
                        ],
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (index * 30).ms, duration: 250.ms)
        .slideX(begin: 0.04, end: 0);
  }
}

class _DataPill extends StatelessWidget {
  const _DataPill({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5.r),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 9.sp, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label, required this.active,
    required this.color, required this.onTap,
  });
  final String label;
  final bool   active;
  final Color  color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
        decoration: BoxDecoration(
          color:        active ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20.r),
          border:       Border.all(color: color.withOpacity(active ? 0 : 0.3)),
          boxShadow: active ? [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp, fontWeight: FontWeight.w600,
            color: active ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyCalendar extends StatelessWidget {
  const _EmptyCalendar({required this.lang, required this.isDark});
  final String lang;
  final bool   isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 90.w, height: 90.w,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF5252).withOpacity(0.15),
                const Color(0xFFFF8A65).withOpacity(0.1),
              ],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.event_available_outlined,
              size: 44.sp, color: const Color(0xFFFF5252).withOpacity(0.6)),
        ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
        SizedBox(height: 16.h),
        Text(
          lang == 'fa' ? 'رویدادی پیدا نشد' : 'No events found',
          style: TextStyle(
            fontSize: 16.sp, fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          lang == 'fa' ? 'فیلتر رو تغییر بده یا صبر کن' : 'Try a different filter or pull to refresh',
          style: TextStyle(fontSize: 12.sp,
              color: isDark ? Colors.white30 : Colors.black38),
        ),
      ],
    );
  }
}
