import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/alert_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';

class AddAlertScreen extends StatefulWidget {
  const AddAlertScreen({super.key});

  @override
  State<AddAlertScreen> createState() => _AddAlertScreenState();
}

class _AddAlertScreenState extends State<AddAlertScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _symbolCtrl = TextEditingController();
  final _priceCtrl  = TextEditingController();

  double? _currentPrice;
  String? _resolvedSymbol;
  bool    _fetchingPrice = false;

  // نمادهای پرکاربرد
  final _quickSymbols = ['XAUUSD', 'EURUSD', 'BTCUSD', 'GBPUSD', 'USDJPY'];

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
        _currentPrice   = (data['price'] as num).toDouble();
        _resolvedSymbol = data['resolved_symbol'] as String?;
        _fetchingPrice  = false;
      });
    } else {
      setState(() => _fetchingPrice = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok   = await context.read<AlertProvider>().createAlert(
      userId:      auth.userId!,
      symbol:      _symbolCtrl.text.trim(),
      targetPrice: double.parse(_priceCtrl.text.trim()),
      username:    auth.username,
    );
    final lang = context.read<LocaleProvider>().lang;
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.t(AppStrings.alertSetSuccess, lang)),
        backgroundColor: AppTheme.green,
      ));
      context.pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            context.read<AlertProvider>().error ?? 'Error'),
        backgroundColor: AppTheme.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    final lang     = context.watch<LocaleProvider>().lang;
    final isRtl    = lang == 'fa';
    final s        = AppStrings.t;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(s(AppStrings.addAlert, lang)),
          backgroundColor: AppTheme.background,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── نمادهای سریع ────────────────────────────────
                Text(
                  lang == 'fa' ? 'نمادهای محبوب' : 'Popular Symbols',
                  style: const TextStyle(
                      color: AppTheme.textSecond, fontSize: 13),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickSymbols.length,
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () {
                        _symbolCtrl.text = _quickSymbols[i];
                        _fetchPrice();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _symbolCtrl.text == _quickSymbols[i]
                              ? AppTheme.primary.withOpacity(0.2)
                              : AppTheme.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _symbolCtrl.text == _quickSymbols[i]
                                ? AppTheme.primary
                                : AppTheme.border,
                          ),
                        ),
                        child: Text(
                          _quickSymbols[i],
                          style: TextStyle(
                            color: _symbolCtrl.text == _quickSymbols[i]
                                ? AppTheme.primary
                                : AppTheme.textSecond,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ).animate().fadeIn(
                        duration: 200.ms,
                        delay: Duration(milliseconds: i * 50)),
                  ),
                ),
                const SizedBox(height: 20),

                // ── نماد ────────────────────────────────────────
                Text(s(AppStrings.symbol, lang),
                    style: const TextStyle(
                        color: AppTheme.textSecond, fontSize: 13)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _symbolCtrl,
                      textCapitalization: TextCapitalization.characters,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1),
                      decoration: InputDecoration(
                        hintText: s(AppStrings.symbolHint, lang),
                        prefixIcon: const Icon(Icons.candlestick_chart_rounded,
                            color: AppTheme.primary),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? s(AppStrings.symbolRequired, lang) : null,
                      onFieldSubmitted: (_) => _fetchPrice(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _GradientButton(
                    onTap: _fetchingPrice ? null : _fetchPrice,
                    child: _fetchingPrice
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(s(AppStrings.getPrice, lang),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                  ),
                ]),

                // کارت قیمت فعلی
                if (_currentPrice != null) ...[
                  const SizedBox(height: 12),
                  _PriceCard(
                    symbol: _resolvedSymbol ?? _symbolCtrl.text,
                    price: _currentPrice!,
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1),
                ],

                const SizedBox(height: 20),

                // ── قیمت هدف ─────────────────────────────────────
                Text(s(AppStrings.targetPrice, lang),
                    style: const TextStyle(
                        color: AppTheme.textSecond, fontSize: 13)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: s(AppStrings.priceHint, lang),
                    prefixIcon: const Icon(Icons.flag_rounded,
                        color: AppTheme.primary),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return s(AppStrings.priceRequired, lang);
                    if (double.tryParse(v.trim()) == null)
                      return s(AppStrings.priceMustBeNumber, lang);
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // راهنما
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppTheme.primary.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: AppTheme.primary, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s(AppStrings.autoDetect, lang),
                        style: const TextStyle(
                            color: AppTheme.textSecond, fontSize: 12),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 32),

                // دکمه ثبت
                _GradientButton(
                  onTap: provider.status == AlertStatus.loading
                      ? null : _submit,
                  fullWidth: true,
                  height: 54,
                  child: provider.status == AlertStatus.loading
                      ? const SizedBox(
                          height: 22, width: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(s(AppStrings.setAlert, lang),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                ).animate().fadeIn(duration: 300.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── کارت قیمت فعلی ────────────────────────────────────────────────────────────

class _PriceCard extends StatelessWidget {
  final String symbol;
  final double price;

  const _PriceCard({required this.symbol, required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.green.withOpacity(0.1),
            AppTheme.green.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.green.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppTheme.green.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.price_check_rounded,
              color: AppTheme.green, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(symbol,
                style: const TextStyle(
                    color: AppTheme.textSecond, fontSize: 12)),
            Text(
              price.toStringAsFixed(price >= 100 ? 2 : 5),
              style: const TextStyle(
                  color: AppTheme.green,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ]),
    );
  }
}

// ── دکمه گرادیانت ─────────────────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool fullWidth;
  final double height;

  const _GradientButton({
    required this.child,
    this.onTap,
    this.fullWidth = false,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1.0,
        duration: 200.ms,
        child: Container(
          height: height,
          width: fullWidth ? double.infinity : null,
          padding: fullWidth ? null : const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, Color(0xFF9C27B0)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
