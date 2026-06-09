import 'package:flutter/material.dart';
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
        appBar: AppBar(title: Text(s(AppStrings.addAlert, lang))),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(s(AppStrings.symbol, lang),
                    style: const TextStyle(
                        color: AppTheme.textSecond, fontSize: 13)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _symbolCtrl,
                      textCapitalization: TextCapitalization.characters,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: s(AppStrings.symbolHint, lang),
                        prefixIcon: const Icon(Icons.candlestick_chart,
                            color: AppTheme.primary),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? s(AppStrings.symbolRequired, lang) : null,
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
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(s(AppStrings.getPrice, lang)),
                    ),
                  ),
                ]),

                if (_currentPrice != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Row(children: [
                      const Icon(Icons.price_check,
                          color: AppTheme.green, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '${_resolvedSymbol ?? _symbolCtrl.text}: $_currentPrice',
                        style: const TextStyle(
                            color: AppTheme.green,
                            fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ),
                ],

                const SizedBox(height: 20),

                Text(s(AppStrings.targetPrice, lang),
                    style: const TextStyle(
                        color: AppTheme.textSecond, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: s(AppStrings.priceHint, lang),
                    prefixIcon: const Icon(Icons.flag_outlined,
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

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline,
                        color: AppTheme.primary, size: 16),
                    const SizedBox(width: 8),
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
                ElevatedButton(
                  onPressed: provider.status == AlertStatus.loading
                      ? null : _submit,
                  child: provider.status == AlertStatus.loading
                      ? const SizedBox(
                          height: 22, width: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(s(AppStrings.setAlert, lang)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
