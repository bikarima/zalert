import 'package:flutter/material.dart';
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

  // آیکون‌های هر اسلاید
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
    final lang = context.watch<LocaleProvider>().lang;
    final items = AppStrings.onboarding;
    final isLast = _page == items.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // دکمه Skip
            Align(
              alignment: lang == 'fa'
                  ? Alignment.topLeft
                  : Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  AppStrings.t(AppStrings.skip, lang),
                  style: const TextStyle(color: AppTheme.textSecond),
                ),
              ),
            ),

            // صفحات
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  return _OnboardingPage(
                    icon: _icons[i],
                    gradientColors: _gradients[i],
                    title: AppStrings.t(item['title']!, lang),
                    desc: AppStrings.t(item['desc']!, lang),
                    isRtl: lang == 'fa',
                  );
                },
              ),
            ),

            // اندیکاتور
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                items.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _page == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _page == i
                        ? AppTheme.primary
                        : AppTheme.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // دکمه بعدی / شروع
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ElevatedButton(
                onPressed: () {
                  if (isLast) {
                    _finish();
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Text(
                  isLast
                      ? AppStrings.t(AppStrings.getStarted, lang)
                      : AppStrings.t(AppStrings.next, lang),
                ),
              ),
            ),
            const SizedBox(height: 32),
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
    required this.icon,
    required this.gradientColors,
    required this.title,
    required this.desc,
    required this.isRtl,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // دایره گرادیانت با آیکون
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors[0].withOpacity(0.4),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Icon(icon, size: 70, color: Colors.white),
            ),
            const SizedBox(height: 48),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textSecond,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
