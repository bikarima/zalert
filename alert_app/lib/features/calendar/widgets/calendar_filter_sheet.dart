import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/calendar_filter.dart';
import '../../../core/theme/app_theme.dart';

class CalendarFilterSheet extends StatefulWidget {
  final CalendarFilter initial;
  final String lang;

  const CalendarFilterSheet({
    super.key,
    required this.initial,
    required this.lang,
  });

  @override
  State<CalendarFilterSheet> createState() => _CalendarFilterSheetState();
}

class _CalendarFilterSheetState extends State<CalendarFilterSheet> {
  late Set<String> _impacts;
  late Set<String> _currencies;

  final _allImpacts = ['high', 'medium', 'low', 'holiday'];
  final _allCurrencies = ['USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF', 'CNY', 'NZD'];

  final _impactLabels = {
    'high':    ('🔴', 'High'),
    'medium':  ('🟠', 'Medium'),
    'low':     ('🟡', 'Low'),
    'holiday': ('⚪', 'Holiday'),
  };

  final _impactColors = {
    'high':    AppTheme.red,
    'medium':  AppTheme.orange,
    'low':     const Color(0xFFFFD600),
    'holiday': AppTheme.blue,
  };

  @override
  void initState() {
    super.initState();
    _impacts    = Set.from(widget.initial.impacts);
    _currencies = Set.from(widget.initial.currencies);
  }

  bool get _fa => widget.lang == 'fa';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // handle
          Center(
            child: Container(
              width: 40.w, height: 4.h,
              decoration: BoxDecoration(
                color: AppTheme.border(context),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // عنوان
          Row(children: [
            Icon(Icons.filter_list_rounded, color: AppTheme.primary, size: 20.sp),
            SizedBox(width: 8.w),
            Text(_fa ? 'فیلتر تقویم' : 'Calendar Filter',
                style: TextStyle(color: AppTheme.text(context),
                    fontSize: 16.sp, fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                _impacts    = Set.from(_allImpacts);
                _currencies = Set.from(_allCurrencies);
              }),
              child: Text(_fa ? 'همه' : 'All',
                  style: TextStyle(color: AppTheme.primary, fontSize: 12.sp)),
            ),
          ]),
          SizedBox(height: 16.h),

          // ── Expected Impact ─────────────────────────────────────
          Text(_fa ? 'اهمیت' : 'Expected Impact',
              style: TextStyle(color: AppTheme.textSec(context),
                  fontSize: 12.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 10.h),
          Row(children: _allImpacts.map((imp) {
            final selected = _impacts.contains(imp);
            final label    = _impactLabels[imp]!;
            final color    = _impactColors[imp]!;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _impacts.remove(imp);
                  } else {
                    _impacts.add(imp);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: EdgeInsets.only(right: 6.w),
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withOpacity(0.15)
                        : AppTheme.card(context),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: selected ? color : AppTheme.border(context),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(label.$1, style: TextStyle(fontSize: 18.sp)),
                    SizedBox(height: 3.h),
                    Text(label.$2,
                        style: TextStyle(
                            color: selected ? color : AppTheme.textSec(context),
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            );
          }).toList()),
          SizedBox(height: 20.h),

          // ── Currencies ──────────────────────────────────────────
          Row(children: [
            Text(_fa ? 'ارزها' : 'Currencies',
                style: TextStyle(color: AppTheme.textSec(context),
                    fontSize: 12.sp, fontWeight: FontWeight.w600)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _currencies = Set.from(_allCurrencies)),
              child: Text(_fa ? 'همه' : 'All',
                  style: TextStyle(color: AppTheme.primary, fontSize: 11.sp)),
            ),
            SizedBox(width: 12.w),
            GestureDetector(
              onTap: () => setState(() => _currencies.clear()),
              child: Text(_fa ? 'هیچ' : 'None',
                  style: TextStyle(color: AppTheme.textSec(context), fontSize: 11.sp)),
            ),
          ]),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: _allCurrencies.map((cur) {
              final selected = _currencies.contains(cur);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) _currencies.remove(cur);
                  else          _currencies.add(cur);
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primary.withOpacity(0.15)
                        : AppTheme.card(context),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: selected ? AppTheme.primary : AppTheme.border(context),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(cur,
                      style: TextStyle(
                        color: selected ? AppTheme.primary : AppTheme.textSec(context),
                        fontSize: 12.sp,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      )),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 24.h),

          // دکمه‌ها
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, null),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.border(context)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r)),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                ),
                child: Text(_fa ? 'انصراف' : 'Cancel',
                    style: TextStyle(
                        color: AppTheme.textSec(context), fontSize: 13.sp)),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(
                  context,
                  CalendarFilter(impacts: _impacts, currencies: _currencies),
                ),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r)),
                ),
                child: Text(_fa ? 'اعمال فیلتر' : 'Apply Filter',
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
