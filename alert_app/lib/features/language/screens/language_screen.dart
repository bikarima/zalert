import 'package:flutter/material.dart';
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // آیکون
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.language,
                    size: 44, color: AppTheme.primary),
              ),
              const SizedBox(height: 28),

              Text(
                'زبان خود را انتخاب کنید\nSelect your language',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 48),

              // کارت‌های زبان
              ...List.generate(_languages.length, (i) {
                final l = _languages[i];
                final selected = _selected == l['code'];
                return GestureDetector(
                  onTap: () => setState(() => _selected = l['code']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 18),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.primary.withOpacity(0.15)
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? AppTheme.primary
                            : AppTheme.divider,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(l['flag']!, style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 16),
                        Text(
                          l['label']!,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? AppTheme.primary
                                : AppTheme.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (selected)
                          const Icon(Icons.check_circle,
                              color: AppTheme.primary),
                      ],
                    ),
                  ),
                );
              }),

              const Spacer(),

              // دکمه ادامه
              ElevatedButton(
                onPressed: () async {
                  await context.read<LocaleProvider>().setLang(_selected);
                  if (context.mounted) context.go('/onboarding');
                },
                child: Text(AppStrings.t(AppStrings.continueBtn, _selected)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
