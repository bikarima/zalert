import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';

// ── Main screen ───────────────────────────────────────────────────────────────

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
                // App icon
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
                  style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold,
                      color: AppTheme.text(context)),
                ),
                SizedBox(height: 6.h),
                Text(
                  lang == 'fa' ? 'روش ورود را انتخاب کنید' : 'Choose your login method',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSec(context), fontSize: 13.sp),
                ),
                SizedBox(height: 24.h),

                // Tabs
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
                    labelStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
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

                SizedBox(
                  height: 380.h,
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

// ── Telegram tab — 2-step OTP flow ───────────────────────────────────────────

enum _TelegramStep { enterUserId, enterOtp }

class _TelegramLoginTab extends StatefulWidget {
  final String lang;
  const _TelegramLoginTab({required this.lang});
  @override
  State<_TelegramLoginTab> createState() => _TelegramLoginTabState();
}

class _TelegramLoginTabState extends State<_TelegramLoginTab> {
  final _idCtrl   = TextEditingController();
  final _nameCtrl = TextEditingController();

  _TelegramStep _step      = _TelegramStep.enterUserId;
  int           _countdown = 300;  // 5 min in seconds
  bool          _canResend = false;
  Timer?        _timer;

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdown = 300;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_countdown > 0) {
          _countdown--;
          if (_countdown == 240) _canResend = true;  // resend after 60s
        } else {
          _canResend = true;
          t.cancel();
        }
      });
    });
  }

  String get _countdownText {
    final m = _countdown ~/ 60;
    final s = _countdown % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _sendCode() async {
    if (_idCtrl.text.trim().isEmpty) return;
    final ok = await context.read<AuthProvider>().requestOtp(
      _idCtrl.text, username: _nameCtrl.text,
    );
    if (!mounted) return;
    if (ok) {
      setState(() => _step = _TelegramStep.enterOtp);
      _startCountdown();
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend) return;
    await _sendCode();
  }

  void _goBackToStep1() {
    _timer?.cancel();
    setState(() => _step = _TelegramStep.enterUserId);
    
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0.1, 0), end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: _step == _TelegramStep.enterUserId
          ? _Step1(
              key: const ValueKey('step1'),
              idCtrl:   _idCtrl,
              nameCtrl: _nameCtrl,
              lang:     widget.lang,
              onSend:   _sendCode,
            )
          : _Step2(
              key:       const ValueKey('step2'),
              userId:    _idCtrl.text,
              username:  _nameCtrl.text,
              lang:      widget.lang,
              countdown: _countdownText,
              countdownSeconds: _countdown,
              canResend: _canResend,
              onResend:  _resendCode,
              onBack:    _goBackToStep1,
              onVerified: () => context.go('/dashboard'),
            ),
    );
  }
}

// ── Step 1: Enter Telegram ID ─────────────────────────────────────────────────

class _Step1 extends StatelessWidget {
  const _Step1({
    super.key,
    required this.idCtrl,
    required this.nameCtrl,
    required this.lang,
    required this.onSend,
  });

  final TextEditingController idCtrl;
  final TextEditingController nameCtrl;
  final String lang;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Info card
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
              Icon(Icons.security_outlined, color: AppTheme.primary, size: 16.sp),
              SizedBox(width: 8.w),
              Expanded(child: Text(
                lang == 'fa'
                    ? 'برای تأیید هویت، یک کد به تلگرامت میفرسته. فقط صاحب واقعی این حساب میتونه وارد بشه.'
                    : 'To verify your identity, a code will be sent to your Telegram. Only the real account owner can log in.',
                style: TextStyle(
                    color: AppTheme.textSec(context), fontSize: 11.sp),
              )),
            ],
          ),
        ),
        SizedBox(height: 14.h),

        // Telegram ID field
        TextField(
          controller: idCtrl,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(color: AppTheme.text(context), fontSize: 14.sp,
              fontFamily: 'TexGyreAdventor'),
          decoration: InputDecoration(
            labelText: lang == 'fa' ? 'آیدی عددی تلگرام' : 'Telegram Numeric ID',
            hintText:  lang == 'fa' ? 'مثال: 123456789' : 'e.g. 123456789',
            prefixIcon: Icon(Icons.person_outline,
                color: AppTheme.primary, size: 18.sp),
          ),
        ),
        SizedBox(height: 10.h),

        // Username (optional)
        TextField(
          controller: nameCtrl,
          style: TextStyle(color: AppTheme.text(context), fontSize: 14.sp),
          decoration: InputDecoration(
            labelText: lang == 'fa' ? 'نام کاربری (اختیاری)' : 'Username (optional)',
            hintText:  lang == 'fa' ? 'مثال: Ali' : 'e.g. Ali',
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
          onPressed: auth.loading ? null : onSend,
          icon: auth.loading
              ? SizedBox(width: 16.w, height: 16.w,
                  child: const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Icon(Icons.send_rounded, size: 16.sp),
          label: Text(lang == 'fa' ? 'ارسال کد تأیید' : 'Send Verification Code'),
        ),
        SizedBox(height: 12.h),

        // Help: how to find Telegram ID
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
              lang == 'fa'
                  ? 'آیدی عددی رو از @userinfobot در تلگرام بگیر'
                  : 'Get your numeric ID from @userinfobot on Telegram',
              style: TextStyle(
                  color: AppTheme.textSec(context), fontSize: 11.sp),
            )),
          ]),
        ),
      ],
    );
  }
}

// ── Step 2: Enter OTP ─────────────────────────────────────────────────────────

class _Step2 extends StatefulWidget {
  const _Step2({
    super.key,
    required this.userId,
    required this.username,
    required this.lang,
    required this.countdown,
    required this.countdownSeconds,
    required this.canResend,
    required this.onResend,
    required this.onBack,
    required this.onVerified,
  });

  final String userId;
  final String username;
  final String lang;
  final String countdown;
  final int    countdownSeconds;
  final bool    canResend;
  final VoidCallback onResend;
  final VoidCallback onBack;
  final VoidCallback onVerified;

  @override
  State<_Step2> createState() => _Step2State();
}

class _Step2State extends State<_Step2> {
  final List<TextEditingController> _ctrls = List.generate(6, (_) => TextEditingController());
  final List<FocusNode>             _nodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    for (final f in _nodes) f.dispose();
    super.dispose();
  }

  String get _code => _ctrls.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_code.length < 6) return;
    final ok = await context.read<AuthProvider>().verifyOtp(
      widget.userId, _code, username: widget.username,
    );
    if (!mounted) return;
    if (ok) widget.onVerified();
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < 5) _nodes[index + 1].requestFocus();
      if (index == 5) {
        _nodes[index].unfocus();
        _verify();
      }
    } else if (value.isEmpty && index > 0) {
      _nodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
    final lang    = widget.lang;
    final isFull  = _code.length == 6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success hint
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: const Color(0xFF00C853).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: const Color(0xFF00C853).withOpacity(0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Color(0xFF00C853), size: 16),
              SizedBox(width: 8.w),
              Expanded(child: Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 11.sp),
                  children: [
                    TextSpan(
                      text: lang == 'fa' ? 'کد تأیید به تلگرام ' : 'Code sent to Telegram ',
                      style: TextStyle(color: AppTheme.textSec(context)),
                    ),
                    TextSpan(
                      text: widget.userId,
                      style: const TextStyle(color: Color(0xFF00C853),
                          fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: lang == 'fa' ? ' ارسال شد.' : ' was sent.',
                      style: TextStyle(color: AppTheme.textSec(context)),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
        SizedBox(height: 20.h),

        // OTP input boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(6, (i) => _OtpBox(
            controller: _ctrls[i],
            focusNode:  _nodes[i],
            onChanged:  (v) => _onDigitChanged(i, v),
          )),
        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
        SizedBox(height: 16.h),

        // Countdown timer
        Center(child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined,
                size: 14.sp,
                color: widget.countdownSeconds > 0
                    ? AppTheme.primary
                    : AppTheme.textSec(context)),
            SizedBox(width: 4.w),
            Text(
              widget.countdownSeconds > 0
                  ? (lang == 'fa'
                      ? 'اعتبار کد: ${widget.countdown}'
                      : 'Code expires in: ${widget.countdown}')
                  : (lang == 'fa' ? 'کد منقضی شد' : 'Code expired'),
              style: TextStyle(
                fontSize: 12.sp,
                color: widget.countdownSeconds > 0 ? AppTheme.primary : AppTheme.textSec(context),
                fontWeight: FontWeight.w600,
                fontFamily: 'TexGyreAdventor',
              ),
            ),
          ],
        )),
        SizedBox(height: 16.h),

        if (auth.error != null) ...[
          _ErrorBox(error: auth.error!),
          SizedBox(height: 12.h),
        ],

        // Verify button
        ElevatedButton(
          onPressed: (auth.loading || !isFull) ? null : _verify,
          child: auth.loading
              ? SizedBox(width: 20.w, height: 20.w,
                  child: const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(lang == 'fa' ? 'تأیید و ورود' : 'Verify & Sign In'),
        ),
        SizedBox(height: 10.h),

        // Resend + back row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Back button
            TextButton.icon(
              onPressed: widget.onBack,
              icon: Icon(Icons.arrow_back_ios_rounded,
                  size: 12.sp, color: AppTheme.textSec(context)),
              label: Text(
                lang == 'fa' ? 'تغییر شماره' : 'Change ID',
                style: TextStyle(
                    fontSize: 12.sp, color: AppTheme.textSec(context)),
              ),
            ),
            // Resend button
            TextButton(
              onPressed: widget.canResend ? widget.onResend : null,
              child: Text(
                lang == 'fa' ? 'ارسال مجدد کد' : 'Resend code',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: widget.canResend
                      ? AppTheme.primary
                      : AppTheme.textSec(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── OTP input box ─────────────────────────────────────────────────────────────

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode             focusNode;
  final ValueChanged<String>  onChanged;

  @override
  Widget build(BuildContext context) {
    final filled = controller.text.isNotEmpty;
    return SizedBox(
      width: 42.w, height: 52.h,
      child: TextField(
        controller:      controller,
        focusNode:       focusNode,
        keyboardType:    TextInputType.number,
        textAlign:       TextAlign.center,
        maxLength:       1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(
          fontSize: 22.sp, fontWeight: FontWeight.bold,
          fontFamily: 'TexGyreAdventor',
          color: AppTheme.text(context),
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide(
              color: filled
                  ? AppTheme.primary
                  : AppTheme.border(context),
              width: filled ? 2 : 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide(color: AppTheme.primary, width: 2),
          ),
          filled: true,
          fillColor: filled
              ? AppTheme.primary.withOpacity(0.08)
              : AppTheme.surface(context),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

// ── Device login tab ──────────────────────────────────────────────────────────

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
    final ok = await context.read<AuthProvider>().loginWithDevice(_nameCtrl.text);
    if (ok && mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final lang = widget.lang;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                style: TextStyle(color: AppTheme.textSec(context), fontSize: 11.sp),
              )),
            ],
          ),
        ),
        SizedBox(height: 14.h),
        TextField(
          controller: _nameCtrl,
          style: TextStyle(color: AppTheme.text(context), fontSize: 14.sp),
          decoration: InputDecoration(
            labelText: lang == 'fa' ? 'نام کاربری (اختیاری)' : 'Username (optional)',
            hintText:  lang == 'fa' ? 'مثال: Ali' : 'e.g. Ali',
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
              ? SizedBox(width: 16.w, height: 16.w,
                  child: const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Icon(Icons.phone_android, size: 18.sp),
          label: Text(lang == 'fa' ? 'ورود با دستگاه' : 'Login with Device'),
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
                    ? 'اگه اپ رو حذف کنی، حسابت از دست میره.'
                    : 'If you uninstall the app, your account will be lost.',
                style: TextStyle(color: AppTheme.orange, fontSize: 10.sp),
              )),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Error box ─────────────────────────────────────────────────────────────────

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

// Extension to clear error from outside
// auth error is cleared by calling requestOtp again
