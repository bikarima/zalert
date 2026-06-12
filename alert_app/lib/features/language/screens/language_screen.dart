import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});
  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selected = 'fa';

  final _languages = [
    {'code': 'fa', 'label': 'فارسی', 'flag': '🇮🇷'},
    {'code': 'en', 'label': 'English', 'flag': '🇬🇧'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              Container(
                width: 80.w, height: 80.w,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.language, size: 40.sp, color: AppTheme.primary),
              ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
              SizedBox(height: 24.h),

              Text(
                'زبان خود را انتخاب کنید\nSelect your language',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18.sp, fontWeight: FontWeight.bold,
                  color: AppTheme.text(context), height: 1.6,
                ),
              ),
              SizedBox(height: 40.h),

              ...List.generate(_languages.length, (i) {
                final l = _languages[i];
                final selected = _selected == l['code'];
                final activeColor = selected ? AppTheme.primary : AppTheme.border(context);

                return GestureDetector(
                  onTap: () => setState(() => _selected = l['code']!),
                  child: AnimatedContainer(
                    duration: 200.ms,
                    margin: EdgeInsets.only(bottom: 14.h),
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.primary.withOpacity(0.12)
                          : AppTheme.surface(context),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: activeColor, width: selected ? 2 : 1),
                    ),
                    child: Row(children: [
                      Text(l['flag']!, style: TextStyle(fontSize: 26.sp)),
                      SizedBox(width: 14.w),
                      Text(l['label']!,
                          style: TextStyle(
                              fontSize: 16.sp, fontWeight: FontWeight.w600,
                              color: selected ? AppTheme.primary : AppTheme.text(context))),
                      const Spacer(),
                      if (selected)
                        Icon(Icons.check_circle, color: AppTheme.primary, size: 20.sp),
                    ]),
                  ),
                ).animate().fadeIn(duration: 200.ms, delay: Duration(milliseconds: i * 80));
              }),

              const Spacer(),

              ElevatedButton(
                onPressed: () async {
                  await context.read<LocaleProvider>().setLang(_selected);
                  if (context.mounted) context.go('/onboarding');
                },
                child: Text(AppStrings.t(AppStrings.continueBtn, _selected)),
              ),
              SizedBox(height: 28.h),
            ],
          ),
        ),
      ),
    );
  }
}
