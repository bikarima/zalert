import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/providers/auth_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang   = context.watch<LocaleProvider>().lang;
    final isRtl  = lang == 'fa';
    final isDark = context.watch<ThemeProvider>().isDark;
    final auth   = context.watch<AuthProvider>();

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
        body: CustomScrollView(
          slivers: [

            // ── Gradient header ──────────────────────────────────────
            SliverAppBar(
              expandedHeight: 110.h,
              floating: false, pinned: true,
              backgroundColor: Colors.transparent, elevation: 0,
              leading: IconButton(
                icon: Icon(
                  isRtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_rounded,
                  color: Colors.white, size: 18.sp,
                ),
                onPressed: () => context.pop(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1565C0), AppTheme.primary, Color(0xFF00B0FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 14.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(children: [
                            Container(
                              width: 36.w, height: 36.w,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.settings_rounded,
                                  color: Colors.white, size: 18.sp),
                            ),
                            SizedBox(width: 12.w),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang == 'fa' ? 'تنظیمات' : 'Settings',
                                  style: TextStyle(
                                    fontSize: 20.sp, fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                if (auth.username != null)
                                  Text(
                                    auth.username!,
                                    style: TextStyle(fontSize: 11.sp, color: Colors.white70),
                                  ),
                              ],
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 100.h),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── ظاهر / Appearance ───────────────────────────────
                  _Section(
                    title: lang == 'fa' ? 'ظاهر' : 'Appearance',
                    icon: Icons.palette_outlined,
                    color: AppTheme.primary,
                    tiles: [
                      _Tile(
                        icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                        title: lang == 'fa' ? 'حالت تاریک' : 'Dark Mode',
                        subtitle: isDark
                            ? (lang == 'fa' ? 'فعال' : 'On')
                            : (lang == 'fa' ? 'غیرفعال' : 'Off'),
                        color: AppTheme.primary,
                        trailing: Switch(
                          value: isDark,
                          onChanged: (_) => context.read<ThemeProvider>().toggle(),
                          activeColor: AppTheme.primary,
                        ),
                      ),
                      _Tile(
                        icon: Icons.language_outlined,
                        title: lang == 'fa' ? 'زبان' : 'Language',
                        subtitle: lang == 'fa' ? 'فارسی' : 'English',
                        color: AppTheme.blue,
                        trailing: GestureDetector(
                          onTap: () => context.read<LocaleProvider>()
                              .setLang(lang == 'fa' ? 'en' : 'fa'),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12.w, vertical: 5.h),
                            decoration: BoxDecoration(
                              color: AppTheme.blue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(
                                  color: AppTheme.blue.withOpacity(0.3)),
                            ),
                            child: Text(
                              lang == 'fa' ? 'EN' : 'فا',
                              style: TextStyle(
                                color: AppTheme.blue,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14.h),

                  // ── اعلان‌ها / Notifications ────────────────────────
                  _Section(
                    title: lang == 'fa' ? 'اعلان‌ها' : 'Notifications',
                    icon: Icons.notifications_outlined,
                    color: AppTheme.orange,
                    tiles: [
                      _Tile(
                        icon: Icons.tune_rounded,
                        title: lang == 'fa'
                            ? 'تنظیمات اعلان'
                            : 'Notification Settings',
                        subtitle: lang == 'fa'
                            ? 'صدا، لرزش، ساعات سکوت'
                            : 'Sound, vibration, quiet hours',
                        color: AppTheme.orange,
                        onTap: () => context.push('/settings/notifications'),
                        trailing: Icon(isRtl
                            ? Icons.arrow_back_ios_rounded
                            : Icons.arrow_forward_ios_rounded,
                            size: 14.sp,
                            color: AppTheme.textSec(context)),
                      ),
                    ],
                  ),
                  SizedBox(height: 14.h),

                  // ── حساب / Account ──────────────────────────────────
                  _Section(
                    title: lang == 'fa' ? 'حساب' : 'Account',
                    icon: Icons.person_outline,
                    color: AppTheme.green,
                    tiles: [
                      _Tile(
                        icon: Icons.badge_outlined,
                        title: lang == 'fa' ? 'شناسه کاربری' : 'User ID',
                        subtitle: auth.userId?.toString() ?? '-',
                        color: AppTheme.green,
                        trailing: const SizedBox.shrink(),
                      ),
                      _Tile(
                        icon: Icons.logout_rounded,
                        title: lang == 'fa' ? 'خروج از حساب' : 'Sign Out',
                        subtitle: lang == 'fa' ? 'از اپ خارج شو' : 'Log out of the app',
                        color: AppTheme.red,
                        onTap: () => _confirmLogout(context, lang),
                        trailing: Icon(isRtl
                            ? Icons.arrow_back_ios_rounded
                            : Icons.arrow_forward_ios_rounded,
                            size: 14.sp, color: AppTheme.red),
                      ),
                    ],
                  ),
                  SizedBox(height: 14.h),

                  // ── درباره / About ───────────────────────────────────
                  _Section(
                    title: lang == 'fa' ? 'درباره' : 'About',
                    icon: Icons.info_outline,
                    color: AppTheme.textSec(context),
                    tiles: [
                      _Tile(
                        icon: Icons.notifications_active_rounded,
                        title: 'ZAlert',
                        subtitle: lang == 'fa'
                            ? 'سیستم آلرت قیمت MT5'
                            : 'MT5 Price Alert System',
                        color: AppTheme.primary,
                        trailing: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text('v2.0',
                              style: TextStyle(
                                  fontSize: 10.sp,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),

                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, String lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang == 'fa' ? 'خروج از حساب؟' : 'Sign out?'),
        content: Text(
          lang == 'fa'
              ? 'مطمئنی میخوای از حساب خارج بشی؟'
              : 'Are you sure you want to sign out?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang == 'fa' ? 'انصراف' : 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().logout();
              if (context.mounted) context.go('/login');
            },
            child: Text(
              lang == 'fa' ? 'خروج' : 'Sign Out',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section ────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.tiles,
  });

  final String        title;
  final IconData      icon;
  final Color         color;
  final List<Widget>  tiles;

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: Row(children: [
            Icon(icon, size: 13.sp, color: color),
            SizedBox(width: 6.w),
            Text(title,
                style: TextStyle(
                    fontSize: 11.sp,
                    color: color,
                    fontWeight: FontWeight.w700)),
            SizedBox(width: 8.w),
            Expanded(child: Divider(
                color: color.withOpacity(0.25), height: 1)),
          ]),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Column(
            children: tiles.asMap().entries.map((e) {
              final isLast = e.key == tiles.length - 1;
              return Column(children: [
                e.value,
                if (!isLast)
                  Divider(
                      height: 1,
                      indent: 52.w,
                      color: AppTheme.border(context)),
              ]);
            }).toList(),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 200.ms);
  }
}

// ── Tile ───────────────────────────────────────────────────────────────────────

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.trailing,
    this.onTap,
  });

  final IconData      icon;
  final String        title;
  final String        subtitle;
  final Color         color;
  final Widget        trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 2.h),
      leading: Container(
        width: 34.w, height: 34.w,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(9.r),
        ),
        child: Icon(icon, color: color, size: 16.sp),
      ),
      title: Text(title,
          style: TextStyle(
              color: color == AppTheme.red
                  ? AppTheme.red
                  : AppTheme.text(context),
              fontSize: 13.sp,
              fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: TextStyle(
              color: AppTheme.textSec(context), fontSize: 10.sp)),
      trailing: trailing,
    );
  }
}
