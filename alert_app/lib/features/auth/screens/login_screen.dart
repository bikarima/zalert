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

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang  = context.watch<LocaleProvider>().lang;
    final isRtl = lang == 'fa';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.bg(context),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
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
                Text(
                  lang == 'fa' ? 'خوش برگشتی' : 'Welcome Back',
                  style: TextStyle(
                      fontSize: 22.sp, fontWeight: FontWeight.bold,
                      color: AppTheme.text(context)),
                ),
                SizedBox(height: 6.h),
                Text(
                  lang == 'fa' ? 'روش ورود را انتخاب کنید' : 'Choose your login method',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppTheme.textSec(context), fontSize: 13.sp),
                ),
                SizedBox(height: 24.h),

                // تب‌ها
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppTheme.border(context)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppTheme.textSec(context),
                    labelStyle: TextStyle(
                        fontSize: 13.sp, fontWeight: FontWeight.w600),
                    dividerColor: Colors.transparent,
                    padding: EdgeInsets.all(3.w),
                    tabs: [
                      Tab(
                        icon: Icon(Icons.telegram, size: 16.sp),
                        text: lang == 'fa' ? 'تلگرام' : 'Telegram',
                        height: 44.h,
                      ),
                      Tab(
                        icon: Icon(Icons.phone_android, size: 16.sp),
                        text: lang == 'fa' ? 'دستگاه' : 'Device',
                        height: 44.h,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),

                // محتوای تب‌ها
                SizedBox(
                  height: 340.h,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _TelegramLoginTab(lang: lang),
                      _DeviceLoginTab(lang: lang),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── تب ورود با تلگرام ─────────────────────────────────────────────────────────

class _TelegramLoginTab extends StatefulWidget {
  final String lang;
  const _TelegramLoginTab({required this.lang});

  @override
  State<_TelegramLoginTab> createState() => _TelegramLoginTabState();
}

class _TelegramLoginTabState extends State<_TelegramLoginTab> {
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
      _idCtrl.text,
      _nameCtrl.text,
    );
    if (ok && mounted) context.go('/alerts');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final lang = widget.lang;
    final s    = AppStrings.t;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // فیلد آیدی تلگرام
          TextFormField(
            controller: _idCtrl,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            style: TextStyle(color: AppTheme.text(context), fontSize: 14.sp),
            decoration: InputDecoration(
              labelText: s(AppStrings.telegramId, lang),
              hintText: s(AppStrings.telegramIdHint, lang),
              prefixIcon: Icon(Icons.person_outline,
                  color: AppTheme.primary, size: 18.sp),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return s(AppStrings.idRequired, lang);
              }
              if (int.tryParse(v.trim()) == null) {
                return s(AppStrings.idMustBeNumber, lang);
              }
              return null;
            },
          ),
          SizedBox(height: 12.h),

          // فیلد نام کاربری
          TextFormField(
            controller: _nameCtrl,
            style: TextStyle(color: AppTheme.text(context), fontSize: 14.sp),
            decoration: InputDecoration(
              labelText: s(AppStrings.username, lang),
              hintText: s(AppStrings.usernameHint, lang),
              prefixIcon: Icon(Icons.badge_outlined,
                  color: AppTheme.primary, size: 18.sp),
            ),
          ),
          SizedBox(height: 16.h),

          if (auth.error != null) ...[
            _ErrorBox(error: auth.error!),
            SizedBox(height: 12.h),
          ],

          ElevatedButton(
            onPressed: auth.loading ? null : _submit,
            child: auth.loading
                ? SizedBox(
                    width: 20.w, height: 20.w,
                    child: const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(s(AppStrings.loginBtn, lang)),
          ),
          SizedBox(height: 12.h),

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
              Expanded(child: Text(
                s(AppStrings.getIdHint, lang),
                style: TextStyle(
                    color: AppTheme.textSec(context), fontSize: 11.sp),
              )),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── تب ورود با دستگاه ─────────────────────────────────────────────────────────

class _DeviceLoginTab extends StatefulWidget {
  final String lang;
  const _DeviceLoginTab({required this.lang});

  @override
  State<_DeviceLoginTab> createState() => _DeviceLoginTabState();
}

class _DeviceLoginTabState extends State<_DeviceLoginTab> {
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await context.read<AuthProvider>().loginWithDevice(
      _nameCtrl.text,
    );
    if (ok && mounted) context.go('/alerts');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final lang = widget.lang;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // توضیح
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.phone_android, color: AppTheme.primary, size: 16.sp),
              SizedBox(width: 8.w),
              Expanded(child: Text(
                lang == 'fa'
                    ? 'ورود بدون تلگرام — یه شناسه یکتا برای دستگاه شما ساخته میشه'
                    : 'Login without Telegram — a unique ID will be generated for your device',
                style: TextStyle(
                    color: AppTheme.textSec(context), fontSize: 11.sp),
              )),
            ],
          ),
        ),
        SizedBox(height: 14.h),

        // فیلد نام (اختیاری)
        TextFormField(
          controller: _nameCtrl,
          style: TextStyle(color: AppTheme.text(context), fontSize: 14.sp),
          decoration: InputDecoration(
            labelText: lang == 'fa'
                ? 'نام کاربری (اختیاری)'
                : 'Username (optional)',
            hintText: lang == 'fa' ? 'مثال: Ali' : 'e.g. Ali',
            prefixIcon: Icon(Icons.badge_outlined,
                color: AppTheme.primary, size: 18.sp),
          ),
        ),
        SizedBox(height: 16.h),

        if (auth.error != null) ...[
          _ErrorBox(error: auth.error!),
          SizedBox(height: 12.h),
        ],

        ElevatedButton.icon(
          onPressed: auth.loading ? null : _submit,
          icon: auth.loading
              ? SizedBox(
                  width: 16.w, height: 16.w,
                  child: const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Icon(Icons.phone_android, size: 18.sp),
          label: Text(
            lang == 'fa' ? 'ورود با دستگاه' : 'Login with Device',
          ),
        ),
        SizedBox(height: 12.h),

        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppTheme.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppTheme.orange.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_outlined,
                  color: AppTheme.orange, size: 16.sp),
              SizedBox(width: 8.w),
              Expanded(child: Text(
                lang == 'fa'
                    ? 'اگه اپ رو حذف کنی، حسابت از دست میره. برای پشتیبان‌گیری، بعداً از Settings تلگرامت رو sync کن.'
                    : 'If you uninstall the app, your account will be lost. To backup, sync your Telegram from Settings later.',
                style: TextStyle(
                    color: AppTheme.orange, fontSize: 10.sp),
              )),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Error Box ────────────────────────────────────────────────────────────────

class _ErrorBox extends StatelessWidget {
  final String error;
  const _ErrorBox({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppTheme.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppTheme.red.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(Icons.error_outline, color: AppTheme.red, size: 16.sp),
        SizedBox(width: 8.w),
        Expanded(child: Text(error,
            style: TextStyle(color: AppTheme.red, fontSize: 12.sp))),
      ]),
    );
  }
}
