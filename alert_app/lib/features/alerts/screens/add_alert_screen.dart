import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/alert_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class AddAlertScreen extends StatefulWidget {
  const AddAlertScreen({super.key});

  @override
  State<AddAlertScreen> createState() => _AddAlertScreenState();
}

class _AddAlertScreenState extends State<AddAlertScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _symbolCtrl  = TextEditingController();
  final _priceCtrl   = TextEditingController();

  double? _currentPrice;
  String? _resolvedSymbol;
  bool    _fetchingPrice = false;

  @override
  void dispose() {
    _symbolCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPrice() async {
    final sym = _symbolCtrl.text.trim();
    if (sym.isEmpty) return;

    setState(() { _fetchingPrice = true; _currentPrice = null; });

    final data = await context.read<AlertProvider>().getPrice(sym);
    if (data != null && mounted) {
      setState(() {
        _currentPrice    = (data['price'] as num).toDouble();
        _resolvedSymbol  = data['resolved_symbol'] as String?;
        _fetchingPrice   = false;
      });
    } else {
      setState(() { _fetchingPrice = false; });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth   = context.read<AuthProvider>();
    final userId = auth.userId!;
    final ok     = await context.read<AlertProvider>().createAlert(
      userId:      userId,
      symbol:      _symbolCtrl.text.trim(),
      targetPrice: double.parse(_priceCtrl.text.trim()),
      username:    auth.username,
    );

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ آلرت با موفقیت ثبت شد'),
          backgroundColor: AppTheme.green,
        ),
      );
      context.pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<AlertProvider>().error ?? 'خطا'),
          backgroundColor: AppTheme.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('آلرت جدید')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── نماد ───────────────────────────────────────────────
              const Text('نماد',
                  style: TextStyle(color: AppTheme.textSecond, fontSize: 13)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _symbolCtrl,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'XAUUSD',
                        prefixIcon:
                            Icon(Icons.candlestick_chart, color: AppTheme.primary),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'نماد را وارد کنید' : null,
                      onFieldSubmitted: (_) => _fetchPrice(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _fetchingPrice ? null : _fetchPrice,
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(70, 52)),
                      child: _fetchingPrice
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('قیمت'),
                    ),
                  ),
                ],
              ),

              // نمایش قیمت فعلی
              if (_currentPrice != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.price_check,
                          color: AppTheme.green, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '${_resolvedSymbol ?? _symbolCtrl.text}: $_currentPrice',
                        style: const TextStyle(
                            color: AppTheme.green, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],

              if (provider.error != null && provider.status == AlertStatus.error) ...[
                const SizedBox(height: 8),
                Text(provider.error!,
                    style: const TextStyle(color: AppTheme.red, fontSize: 12)),
              ],

              const SizedBox(height: 20),

              // ── قیمت هدف ───────────────────────────────────────────
              const Text('قیمت هدف',
                  style: TextStyle(color: AppTheme.textSecond, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: '3300.50',
                  prefixIcon: Icon(Icons.flag_outlined, color: AppTheme.primary),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'قیمت را وارد کنید';
                  if (double.tryParse(v.trim()) == null) return 'قیمت باید عدد باشد';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // راهنما
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.primary, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ربات خودکار تشخیص میده آلرت برای بالا رفتن یا پایین آمدن باشه',
                        style: TextStyle(
                            color: AppTheme.textSecond, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // دکمه ثبت
              ElevatedButton(
                onPressed: provider.status == AlertStatus.loading ? null : _submit,
                child: provider.status == AlertStatus.loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('ثبت آلرت'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
