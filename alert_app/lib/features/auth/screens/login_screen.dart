import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _idCtrl    = TextEditingController();
  final _nameCtrl  = TextEditingController();

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok   = await auth.login(_idCtrl.text, _nameCtrl.text);
    if (ok && mounted) context.go('/alerts');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // آیکون
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active,
                      size: 40, color: AppTheme.primary),
                ),
                const SizedBox(height: 24),

                const Text(
                  'ربات آلرت MT5',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'آیدی عددی تلگرام خود را وارد کنید',
                  style: TextStyle(color: AppTheme.textSecond, fontSize: 14),
                ),
                const SizedBox(height: 48),

                // فیلد آیدی
                TextFormField(
                  controller: _idCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'آیدی عددی تلگرام',
                    hintText: 'مثال: 123456789',
                    prefixIcon: Icon(Icons.person_outline, color: AppTheme.primary),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'آیدی را وارد کنید';
                    if (int.tryParse(v.trim()) == null) return 'آیدی باید عدد باشد';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // فیلد نام (اختیاری)
                TextFormField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'نام کاربری (اختیاری)',
                    hintText: 'مثال: Ali',
                    prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 32),

                // خطا
                if (auth.error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.red.withOpacity(0.3)),
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
                      : const Text('ورود'),
                ),

                const SizedBox(height: 24),
                const Text(
                  'برای دریافت آیدی عددی خود به @userinfobot در تلگرام پیام بدید',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecond, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
