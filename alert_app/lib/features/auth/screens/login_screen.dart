import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _idCtrl   = TextEditingController();
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await context.read<AuthProvider>().login(
          _idCtrl.text, _nameCtrl.text);
    if (ok && mounted) context.go('/alerts');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final lang = context.watch<LocaleProvider>().lang;
    final isRtl = lang == 'fa';
    final s = AppStrings.t;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),

                  // آیکون
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, Color(0xFF9C27B0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.notifications_active,
                        size: 42, color: Colors.white),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    s(AppStrings.welcomeBack, lang),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s(AppStrings.loginSubtitle, lang),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppTheme.textSecond, fontSize: 14),
                  ),
                  const SizedBox(height: 40),

                  // فیلد آیدی
                  TextFormField(
                    controller: _idCtrl,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: s(AppStrings.telegramId, lang),
                      hintText: s(AppStrings.telegramIdHint, lang),
                      prefixIcon: const Icon(Icons.person_outline,
                          color: AppTheme.primary),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return s(AppStrings.idRequired, lang);
                      if (int.tryParse(v.trim()) == null)
                        return s(AppStrings.idMustBeNumber, lang);
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // فیلد نام
                  TextFormField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: s(AppStrings.username, lang),
                      hintText: s(AppStrings.usernameHint, lang),
                      prefixIcon: const Icon(Icons.badge_outlined,
                          color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // خطا
                  if (auth.error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: AppTheme.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppTheme.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(auth.error!,
                                style: const TextStyle(
                                    color: AppTheme.red, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // دکمه ورود
                  ElevatedButton(
                    onPressed: auth.loading ? null : _submit,
                    child: auth.loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(s(AppStrings.loginBtn, lang)),
                  ),
                  const SizedBox(height: 24),

                  // راهنما
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: AppTheme.primary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            s(AppStrings.getIdHint, lang),
                            style: const TextStyle(
                                color: AppTheme.textSecond, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
