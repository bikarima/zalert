import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
        content: Text(context.read<AlertProvider>().error ?? 'Error'),
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
        backgroundColor: AppTheme.bg(context),
        appBar: AppBar(
          title: Text(s(AppStrings.addAlert, lang)),
          backgroundColor: AppTheme.bg(context),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(18.w),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── نمادهای سریع ───────────────────────────────────
                Text(lang == 'fa' ? 'نمادهای محبوب' : 'Popular Symbols',
                    style: TextStyle(color: AppTheme.textSec(context), fontSize: 12.sp)),
                SizedBox(height: 8.h),
                SizedBox(
                  height: 36.h,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickSymbols.length,
                    itemBuilder: (_, i) {
                      final isActive = _symbolCtrl.text == _quickSymbols[i];
                      return GestureDetector(
                        onTap: () {
                          _symbolCtrl.text = _quickSymbols[i];
                          _fetchPrice();
                        },
                        child: Container(
                          margin: EdgeInsets.only(right: 8.w),
                          padding: EdgeInsets.symmetric(
                              horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppTheme.primary.withOpacity(0.2)
                                : AppTheme.card(context),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: isActive
                                  ? AppTheme.primary
                                  : AppTheme.border(context),
                            ),
                          ),
                          child: Text(
                            _quickSymbols[i],
                            style: TextStyle(
                              color: isActive
                                  ? AppTheme.primary
                                  : AppTheme.textSec(context),
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ).animate().fadeIn(
                          duration: 200.ms,
                          delay: Duration(milliseconds: i * 50));
                    },
                  ),
                ),
                SizedBox(height: 18.h),

                // ── نماد ────────────────────────────────────────────
                Text(s(AppStrings.symbol, lang),
                    style: TextStyle(color: AppTheme.textSec(context), fontSize: 12.sp)),
                SizedBox(height: 6.h),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _symbolCtrl,
                      textCapitalization: TextCapitalization.characters,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(color: AppTheme.text(context),
                          fontWeight: FontWeight.w600, letterSpacing: 1, fontSize: 14.sp),
                      decoration: InputDecoration(
                        hintText: s(AppStrings.symbolHint, lang),
                        prefixIcon: Icon(Icons.candlestick_chart_rounded,
                            color: AppTheme.primary, size: 18.sp),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? s(AppStrings.symbolRequired, lang) : null,
                      onFieldSubmitted: (_) => _fetchPrice(),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  _GradientButton(
                    onTap: _fetchingPrice ? null : _fetchPrice,
                    child: _fetchingPrice
                        ? SizedBox(width: 18.w, height: 18.w,
                            child: const CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(s(AppStrings.getPrice, lang),
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w600, fontSize: 12.sp)),
                  ),
                ]),

                if (_currentPrice != null) ...[
                  SizedBox(height: 10.h),
                  _PriceCard(
                    symbol: _resolvedSymbol ?? _symbolCtrl.text,
                    price: _currentPrice!,
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1),
                ],

                SizedBox(height: 18.h),

                // ── قیمت هدف ─────────────────────────────────────────
                Text(s(AppStrings.targetPrice, lang),
                    style: TextStyle(color: AppTheme.textSec(context), fontSize: 12.sp)),
                SizedBox(height: 6.h),
                TextFormField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: AppTheme.text(context),
                      fontWeight: FontWeight.w600, fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: s(AppStrings.priceHint, lang),
                    prefixIcon: Icon(Icons.flag_rounded,
                        color: AppTheme.primary, size: 18.sp),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return s(AppStrings.priceRequired, lang);
                    if (double.tryParse(v.trim()) == null) return s(AppStrings.priceMustBeNumber, lang);
                    return null;
                  },
                ),
                SizedBox(height: 12.h),

                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    Icon(Icons.auto_awesome_rounded,
                        color: AppTheme.primary, size: 15.sp),
                    SizedBox(width: 8.w),
                    Expanded(child: Text(s(AppStrings.autoDetect, lang),
                        style: TextStyle(
                            color: AppTheme.textSec(context), fontSize: 11.sp))),
                  ]),
                ),

                SizedBox(height: 28.h),

                _GradientButton(
                  onTap: provider.status == AlertStatus.loading ? null : _submit,
                  fullWidth: true,
                  height: 50.h,
                  child: provider.status == AlertStatus.loading
                      ? SizedBox(width: 20.w, height: 20.w,
                          child: const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(s(AppStrings.setAlert, lang),
                          style: TextStyle(color: Colors.white,
                              fontSize: 15.sp, fontWeight: FontWeight.bold)),
                ).animate().fadeIn(duration: 300.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Price Card ────────────────────────────────────────────────────────────────

class _PriceCard extends StatelessWidget {
  final String symbol;
  final double price;
  const _PriceCard({required this.symbol, required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppTheme.green.withOpacity(0.1),
          AppTheme.green.withOpacity(0.03),
        ]),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.green.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width: 34.w, height: 34.w,
          decoration: BoxDecoration(
            color: AppTheme.green.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(Icons.price_check_rounded, color: AppTheme.green, size: 16.sp),
        ),
        SizedBox(width: 10.w),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(symbol, style: TextStyle(
              color: AppTheme.textSec(context), fontSize: 11.sp)),
          Text(
            price.toStringAsFixed(price >= 100 ? 2 : 5),
            style: TextStyle(color: AppTheme.green,
                fontSize: 16.sp, fontWeight: FontWeight.bold),
          ),
        ]),
      ]),
    );
  }
}

// ── Gradient Button ───────────────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool fullWidth;
  final double? height;

  const _GradientButton({
    required this.child,
    this.onTap,
    this.fullWidth = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1.0,
        duration: 200.ms,
        child: Container(
          height: height ?? 46.h,
          width: fullWidth ? double.infinity : null,
          padding: fullWidth ? null : EdgeInsets.symmetric(horizontal: 18.w),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppTheme.primary, Color(0xFF9C27B0)]),
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [BoxShadow(
              color: AppTheme.primary.withOpacity(0.4),
              blurRadius: 10.r, offset: const Offset(0, 4),
            )],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
