import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../providers/notification_settings_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_theme.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<NotificationSettingsProvider>();
    final lang     = context.watch<LocaleProvider>().lang;
    final isRtl    = lang == 'fa';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.bg(context),
        appBar: AppBar(
          backgroundColor: AppTheme.bg(context),
          title: Text(
            lang == 'fa' ? 'تنظیمات اعلان‌ها' : 'Notification Settings',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
          ),
        ),
        body: ListView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          children: [

            // ── وضعیت FCM ─────────────────────────────────────────
            _FcmStatusCard(lang: lang),
            SizedBox(height: 16.h),

            // ── آلرت قیمت ─────────────────────────────────────────
            _SectionHeader(
              icon: Icons.notifications_active_rounded,
              title: lang == 'fa' ? 'آلرت قیمت' : 'Price Alerts',
              color: AppTheme.primary,
            ),
            _ToggleTile(
              icon: Icons.price_check_rounded,
              title: lang == 'fa' ? 'آلرت فعال شد' : 'Alert Triggered',
              subtitle: lang == 'fa'
                  ? 'وقتی قیمت به هدف رسید'
                  : 'When price hits target',
              value: settings.alertTriggered,
              onChanged: settings.setAlertTriggered,
              color: AppTheme.green,
            ),
            _ToggleTile(
              icon: Icons.add_alert_rounded,
              title: lang == 'fa' ? 'تأیید ثبت آلرت' : 'Alert Created',
              subtitle: lang == 'fa'
                  ? 'وقتی آلرت جدید ثبت میشه'
                  : 'When a new alert is set',
              value: settings.alertCreated,
              onChanged: settings.setAlertCreated,
              color: AppTheme.blue,
            ),
            _ToggleTile(
              icon: Icons.volume_up_rounded,
              title: lang == 'fa' ? 'صدای اعلان' : 'Alert Sound',
              subtitle: lang == 'fa' ? 'پخش صدا برای آلرت‌ها' : 'Play sound for alerts',
              value: settings.alertSound,
              onChanged: settings.setAlertSound,
              color: AppTheme.orange,
            ),
            _ToggleTile(
              icon: Icons.vibration_rounded,
              title: lang == 'fa' ? 'لرزش' : 'Vibration',
              subtitle: lang == 'fa' ? 'لرزش گوشی برای آلرت‌ها' : 'Vibrate for alerts',
              value: settings.alertVibration,
              onChanged: settings.setAlertVibration,
              color: AppTheme.primary,
            ),
            SizedBox(height: 16.h),

            // ── تقویم اقتصادی ─────────────────────────────────────
            _SectionHeader(
              icon: Icons.calendar_today_rounded,
              title: lang == 'fa' ? 'تقویم اقتصادی' : 'Economic Calendar',
              color: AppTheme.red,
            ),
            _ToggleTile(
              icon: Icons.alarm_rounded,
              title: lang == 'fa' ? 'یادآوری اخبار' : 'News Reminder',
              subtitle: lang == 'fa'
                  ? 'قبل از اخبار مهم یادآوری بده'
                  : 'Remind before important news',
              value: settings.calendarReminder,
              onChanged: settings.setCalendarReminder,
              color: AppTheme.red,
            ),
            _ToggleTile(
              icon: Icons.fiber_manual_record_rounded,
              title: lang == 'fa' ? 'فقط اخبار قرمز' : 'High Impact Only',
              subtitle: lang == 'fa'
                  ? 'فقط اخبار با تأثیر بالا'
                  : 'Only high impact news',
              value: settings.calendarHighOnly,
              onChanged: settings.setCalendarHighOnly,
              color: AppTheme.red,
              iconColor: AppTheme.red,
            ),

            // slider دقایق یادآوری
            if (settings.calendarReminder) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: _SliderTile(
                  title: lang == 'fa'
                      ? '${settings.calendarMinutes} دقیقه قبل'
                      : '${settings.calendarMinutes} min before',
                  icon: Icons.timer_rounded,
                  value: settings.calendarMinutes.toDouble(),
                  min: 5, max: 60, divisions: 11,
                  label: '${settings.calendarMinutes}m',
                  onChanged: (v) => settings.setCalendarMinutes(v.toInt()),
                  color: AppTheme.orange,
                ),
              ),
            ],
            SizedBox(height: 16.h),

            // ── ساعات سکوت ────────────────────────────────────────
            _SectionHeader(
              icon: Icons.bedtime_rounded,
              title: lang == 'fa' ? 'ساعات سکوت' : 'Quiet Hours',
              color: AppTheme.blue,
            ),
            _ToggleTile(
              icon: Icons.do_not_disturb_on_rounded,
              title: lang == 'fa' ? 'ساعات سکوت' : 'Quiet Hours',
              subtitle: lang == 'fa'
                  ? 'در بازه مشخص اعلان نده'
                  : 'Silence notifications in a time range',
              value: settings.quietHoursEnabled,
              onChanged: settings.setQuietEnabled,
              color: AppTheme.blue,
            ),
            if (settings.quietHoursEnabled) ...[
              Row(children: [
                Expanded(child: _TimeTile(
                  title: lang == 'fa' ? 'شروع' : 'From',
                  hour: settings.quietStart,
                  onChanged: settings.setQuietStart,
                  color: AppTheme.blue,
                )),
                SizedBox(width: 10.w),
                Expanded(child: _TimeTile(
                  title: lang == 'fa' ? 'پایان' : 'To',
                  hour: settings.quietEnd,
                  onChanged: settings.setQuietEnd,
                  color: AppTheme.primary,
                )),
              ]),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
                child: Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: AppTheme.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    settings.isQuietHour
                        ? (lang == 'fa' ? '🔕 الان در ساعت سکوت هستید' : '🔕 Currently in quiet hours')
                        : (lang == 'fa' ? '🔔 الان ساعت سکوت نیست' : '🔔 Not in quiet hours now'),
                    style: TextStyle(
                      color: settings.isQuietHour ? AppTheme.blue : AppTheme.green,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              ),
            ],
            SizedBox(height: 16.h),

            // ── عمومی ─────────────────────────────────────────────
            _SectionHeader(
              icon: Icons.tune_rounded,
              title: lang == 'fa' ? 'عمومی' : 'General',
              color: AppTheme.orange,
            ),
            _ToggleTile(
              icon: Icons.fiber_smart_record_rounded,
              title: lang == 'fa' ? 'نمایش Badge' : 'Show Badge',
              subtitle: lang == 'fa'
                  ? 'تعداد روی آیکون اپ'
                  : 'Count on app icon',
              value: settings.showBadge,
              onChanged: settings.setShowBadge,
              color: AppTheme.orange,
            ),
            SizedBox(height: 16.h),

            // ── تست ───────────────────────────────────────────────
            _TestSection(lang: lang),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }
}

// ── FCM Status Card ───────────────────────────────────────────────────────────

class _FcmStatusCard extends StatelessWidget {
  final String lang;
  const _FcmStatusCard({required this.lang});

  @override
  Widget build(BuildContext context) {
    final token   = NotificationService.instance.fcmToken;
    final hasToken = token != null;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: hasToken
            ? AppTheme.green.withOpacity(0.08)
            : AppTheme.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: hasToken
              ? AppTheme.green.withOpacity(0.3)
              : AppTheme.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              hasToken ? Icons.check_circle_rounded : Icons.error_rounded,
              color: hasToken ? AppTheme.green : AppTheme.red,
              size: 18.sp,
            ),
            SizedBox(width: 8.w),
            Text(
              hasToken
                  ? (lang == 'fa' ? '✅ Push Notification فعاله' : '✅ Push Notifications Active')
                  : (lang == 'fa' ? '❌ Push Token دریافت نشده' : '❌ No Push Token'),
              style: TextStyle(
                color: hasToken ? AppTheme.green : AppTheme.red,
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ]),
          if (hasToken) ...[
            SizedBox(height: 6.h),
            Text(
              'FCM: ${token.substring(0, 30)}...',
              style: TextStyle(
                  color: AppTheme.textSec(context), fontSize: 10.sp),
            ),
          ] else ...[
            SizedBox(height: 6.h),
            Text(
              lang == 'fa'
                  ? 'Firebase هنوز توکن صادر نکرده. از اپ خارج شوید و دوباره وارد شوید.'
                  : 'Firebase hasn\'t issued a token yet. Try logging out and back in.',
              style: TextStyle(color: AppTheme.textSec(context), fontSize: 11.sp),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ── Test Section ──────────────────────────────────────────────────────────────

class _TestSection extends StatefulWidget {
  final String lang;
  const _TestSection({required this.lang});

  @override
  State<_TestSection> createState() => _TestSectionState();
}

class _TestSectionState extends State<_TestSection> {
  bool    _sending = false;
  String? _result;

  Future<void> _test() async {
    setState(() { _sending = true; _result = null; });
    try {
      await NotificationService.instance.showTestNotification(widget.lang);
      setState(() {
        _result  = widget.lang == 'fa'
            ? '✅ اگه نوتیف دیدید، همه چیز اوکه!'
            : '✅ If you see the notification, everything works!';
        _sending = false;
      });
    } catch (e) {
      setState(() { _result = '❌ $e'; _sending = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionHeader(
          icon: Icons.bug_report_rounded,
          title: widget.lang == 'fa' ? 'تست' : 'Test',
          color: AppTheme.textSec(context),
        ),
        Container(
          margin: EdgeInsets.symmetric(vertical: 4.h),
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Column(children: [
            Row(children: [
              Icon(Icons.notifications_outlined,
                  color: AppTheme.primary, size: 18.sp),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  widget.lang == 'fa'
                      ? 'ارسال نوتیف تست'
                      : 'Send Test Notification',
                  style: TextStyle(color: AppTheme.text(context),
                      fontSize: 13.sp, fontWeight: FontWeight.w600),
                ),
              ),
              GestureDetector(
                onTap: _sending ? null : _test,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppTheme.primary, Color(0xFF9C27B0)]),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: _sending
                      ? SizedBox(width: 16.w, height: 16.w,
                          child: const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          widget.lang == 'fa' ? 'ارسال' : 'Send',
                          style: TextStyle(
                              color: Colors.white, fontSize: 12.sp,
                              fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ]),
            if (_result != null) ...[
              SizedBox(height: 8.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: _result!.startsWith('✅')
                      ? AppTheme.green.withOpacity(0.1)
                      : AppTheme.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(_result!,
                    style: TextStyle(
                      color: _result!.startsWith('✅') ? AppTheme.green : AppTheme.red,
                      fontSize: 11.sp,
                    )),
              ),
            ],
          ]),
        ),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _SectionHeader({required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h, top: 4.h),
      child: Row(children: [
        Icon(icon, color: color, size: 15.sp),
        SizedBox(width: 6.w),
        Text(title, style: TextStyle(
            color: color, fontSize: 12.sp, fontWeight: FontWeight.bold)),
        SizedBox(width: 8.w),
        Expanded(child: Divider(color: color.withOpacity(0.3), height: 1)),
      ]),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color color;
  final Color? iconColor;

  const _ToggleTile({
    required this.icon, required this.title, required this.subtitle,
    required this.value, required this.onChanged, required this.color,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 6.h),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 2.h),
        leading: Container(
          width: 36.w, height: 36.w,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9.r),
          ),
          child: Icon(icon, color: iconColor ?? color, size: 17.sp),
        ),
        title: Text(title, style: TextStyle(
            color: AppTheme.text(context), fontSize: 13.sp,
            fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(
            color: AppTheme.textSec(context), fontSize: 10.sp)),
        trailing: Switch(value: value, onChanged: onChanged),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

class _SliderTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final double value;
  final double min, max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;
  final Color color;

  const _SliderTile({
    required this.title, required this.icon, required this.value,
    required this.min, required this.max, required this.divisions,
    required this.label, required this.onChanged, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 6.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(children: [
        Row(children: [
          Icon(icon, color: color, size: 16.sp),
          SizedBox(width: 8.w),
          Text(title, style: TextStyle(
              color: AppTheme.text(context), fontSize: 12.sp,
              fontWeight: FontWeight.w600)),
        ]),
        Slider(
          value: value, min: min, max: max, divisions: divisions,
          label: label, activeColor: color,
          onChanged: onChanged,
        ),
      ]),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String title;
  final int hour;
  final ValueChanged<int> onChanged;
  final Color color;

  const _TimeTile({
    required this.title, required this.hour,
    required this.onChanged, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: hour, minute: 0),
        );
        if (picked != null) onChanged(picked.hour);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(children: [
          Text(title, style: TextStyle(
              color: AppTheme.textSec(context), fontSize: 11.sp)),
          SizedBox(height: 4.h),
          Text(
            '${hour.toString().padLeft(2,'0')}:00',
            style: TextStyle(color: color, fontSize: 18.sp,
                fontWeight: FontWeight.bold),
          ),
        ]),
      ),
    );
  }
}
