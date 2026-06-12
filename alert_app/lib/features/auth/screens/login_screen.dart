import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
    final ok = await context.read<AuthProvider>().login(_idCtrl.text, _nameCtrl.text);
    if (ok && mounted) context.go('/alerts');
  }

  @override
  Widget build(BuildContext context) {
    final auth  = context.watch<AuthProvider>();
    final lang  = context.watch<LocaleProvider>().lang;
    final isRtl = lang == 'fa';
    final s     = AppStrings.t;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.bg(context),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 28.h),

                  // آیکون
                  Container(
                    width: 76.w, height: 76.w,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, Color(0xFF9C27B0)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                        color: AppTheme.primary.withOpacity(0.4),
                        blurRadius: 20.r, offset: const Offset(0, 8),
                      )],
                    ),
                    child: Icon(Icons.notifications_active,
                        size: 36.sp, color: Colors.white),
                  ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

                  SizedBox(height: 20.h),
                  Text(s(AppStrings.welcomeBack, lang),
                      style: TextStyle(
                          fontSize: 22.sp, fontWeight: FontWeight.bold,
                          color: AppTheme.text(context))),
                  SizedBox(height: 6.h),
                  Text(s(AppStrings.loginSubtitle, lang),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.textSec(context), fontSize: 13.sp)),
                  SizedBox(height: 32.h),

                  // فیلد آیدی
                  TextFormField(
                    controller: _idCtrl,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(color: AppTheme.text(context), fontSize: 14.sp),
                    decoration: InputDecoration(
                      labelText: s(AppStrings.telegramId, lang),
                      hintText: s(AppStrings.telegramIdHint, lang),
                      prefixIcon: Icon(Icons.person_outline, color: AppTheme.primary, size: 18.sp),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return s(AppStrings.idRequired, lang);
                      if (int.tryParse(v.trim()) == null) return s(AppStrings.idMustBeNumber, lang);
                      return null;
                    },
                  ),
                  SizedBox(height: 14.h),

                  // فیلد نام
                  TextFormField(
                    controller: _nameCtrl,
                    style: TextStyle(color: AppTheme.text(context), fontSize: 14.sp),
                    decoration: InputDecoration(
                      labelText: s(AppStrings.username, lang),
                      hintText: s(AppStrings.usernameHint, lang),
                      prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.primary, size: 18.sp),
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // خطا
                  if (auth.error != null) ...[
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: AppTheme.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: AppTheme.red.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        Icon(Icons.error_outline, color: AppTheme.red, size: 16.sp),
                        SizedBox(width: 8.w),
                        Expanded(child: Text(auth.error!,
                            style: TextStyle(color: AppTheme.red, fontSize: 12.sp))),
                      ]),
                    ),
                    SizedBox(height: 14.h),
                  ],

                  // دکمه ورود
                  ElevatedButton(
                    onPressed: auth.loading ? null : _submit,
                    child: auth.loading
                        ? SizedBox(width: 20.w, height: 20.w,
                            child: const CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(s(AppStrings.loginBtn, lang)),
                  ),
                  SizedBox(height: 20.h),

                  // راهنما
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppTheme.surface(context),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: AppTheme.border(context)),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline, color: AppTheme.primary, size: 16.sp),
                      SizedBox(width: 8.w),
                      Expanded(child: Text(s(AppStrings.getIdHint, lang),
                          style: TextStyle(
                              color: AppTheme.textSec(context), fontSize: 11.sp))),
                    ]),
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
