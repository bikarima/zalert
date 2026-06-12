import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  final _icons = [
    Icons.notifications_active_outlined,
    Icons.candlestick_chart_outlined,
    Icons.phone_android_outlined,
  ];

  final _gradients = [
    [const Color(0xFF6C63FF), const Color(0xFF3F3D9B)],
    [const Color(0xFF00C9A7), const Color(0xFF00796B)],
    [const Color(0xFFFF6B6B), const Color(0xFFC62828)],
  ];

  Future<void> _finish() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('onboarding_done', true);
    if (mounted) context.go('/login');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang   = context.watch<LocaleProvider>().lang;
    final items  = AppStrings.onboarding;
    final isLast = _page == items.length - 1;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: lang == 'fa' ? Alignment.topLeft : Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(AppStrings.t(AppStrings.skip, lang),
                    style: TextStyle(
                        color: AppTheme.textSec(context), fontSize: 13.sp)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: items.length,
                itemBuilder: (_, i) => _OnboardingPage(
                  icon: _icons[i],
                  gradientColors: _gradients[i],
                  title: AppStrings.t(items[i]['title']!, lang),
                  desc: AppStrings.t(items[i]['desc']!, lang),
                  isRtl: lang == 'fa',
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(items.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.symmetric(horizontal: 4.w),
                width: _page == i ? 22.w : 7.w,
                height: 7.h,
                decoration: BoxDecoration(
                  color: _page == i ? AppTheme.primary : AppTheme.border(context),
                  borderRadius: BorderRadius.circular(4.r),
                ),
              )),
            ),
            SizedBox(height: 28.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 28.w),
              child: ElevatedButton(
                onPressed: () {
                  if (isLast) {
                    _finish();
                  } else {
                    _controller.nextPage(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut);
                  }
                },
                child: Text(isLast
                    ? AppStrings.t(AppStrings.getStarted, lang)
                    : AppStrings.t(AppStrings.next, lang)),
              ),
            ),
            SizedBox(height: 28.h),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final List<Color> gradientColors;
  final String title;
  final String desc;
  final bool isRtl;

  const _OnboardingPage({
    required this.icon, required this.gradientColors,
    required this.title, required this.desc, required this.isRtl,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140.w, height: 140.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
                boxShadow: [BoxShadow(
                  color: gradientColors[0].withOpacity(0.4),
                  blurRadius: 32.r, offset: const Offset(0, 14),
                )],
              ),
              child: Icon(icon, size: 60.sp, color: Colors.white),
            ),
            SizedBox(height: 40.h),
            Text(title, textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20.sp, fontWeight: FontWeight.bold,
                    color: AppTheme.text(context))),
            SizedBox(height: 14.h),
            Text(desc, textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13.sp, color: AppTheme.textSec(context), height: 1.7)),
          ],
        ),
      ),
    );
  }
}
