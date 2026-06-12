import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_theme.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  int _selectedTab = 0;

  final _tabIconsFa = ['ارزش پیپ', 'سایز پوزیشن', 'سود/ضرر'];
  final _tabIconsEn = ['Pip Value', 'Position Size', 'Profit/Loss'];

  @override
  Widget build(BuildContext context) {
    final lang  = context.watch<LocaleProvider>().lang;
    final isRtl = lang == 'fa';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.bg(context),
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppTheme.bg(context),
              title: Text(
                lang == 'fa' ? 'ماشین حساب تریدر' : 'Trader Calculator',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                    color: AppTheme.text(context)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: Column(
                  children: [
                    // Chip Selector
                    _ChipSelector(
                      tabs: lang == 'fa' ? _tabIconsFa : _tabIconsEn,
                      selected: _selectedTab,
                      onSelect: (i) => setState(() => _selectedTab = i),
                    ),
                    SizedBox(height: 20.h),
                    // محتوا
                    AnimatedSwitcher(
                      duration: 300.ms,
                      child: _selectedTab == 0
                          ? _PipCalculator(key: const ValueKey(0), lang: lang)
                          : _selectedTab == 1
                              ? _PositionSizeCalculator(
                                  key: const ValueKey(1), lang: lang)
                              : _PnLCalculator(
                                  key: const ValueKey(2), lang: lang),
                    ),
                    SizedBox(height: 32.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chip Selector ─────────────────────────────────────────────────────────────

class _ChipSelector extends StatelessWidget {
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  const _ChipSelector({
    required this.tabs, required this.selected, required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSelected = i == selected;
          return Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: 200.ms,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary
                      : AppTheme.surface(context),
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.border(context),
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(
                          color: AppTheme.primary.withOpacity(0.3),
                          blurRadius: 8.r, offset: const Offset(0, 4))]
                      : null,
                ),
                child: Text(
                  tabs[i],
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : AppTheme.textSec(context),
                    fontSize: 13.sp,
                    fontWeight: isSelected
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Result Card ───────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final String label;
  final String value;
  final bool isPositive;
  final bool isNeutral;

  const _ResultCard({
    required this.label,
    required this.value,
    this.isPositive = true,
    this.isNeutral = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isNeutral
        ? AppTheme.primary
        : isPositive
            ? AppTheme.green
            : AppTheme.red;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textSec(context),
              fontSize: 12.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 28.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: 300.ms);
  }
}

// ── Input Field ───────────────────────────────────────────────────────────────

class _CalcField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final Widget? prefix;

  const _CalcField({
    required this.controller,
    required this.label,
    this.hint,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textDirection: TextDirection.ltr,
      style: TextStyle(color: AppTheme.text(context), fontSize: 14.sp),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefix,
      ),
    );
  }
}

// ── ۱. Pip Calculator ─────────────────────────────────────────────────────────

class _PipCalculator extends StatefulWidget {
  final String lang;
  const _PipCalculator({super.key, required this.lang});

  @override
  State<_PipCalculator> createState() => _PipCalculatorState();
}

class _PipCalculatorState extends State<_PipCalculator> {
  final _symbolCtrl   = TextEditingController(text: 'EURUSD');
  final _lotCtrl      = TextEditingController(text: '1.00');
  final _rateCtrl     = TextEditingController(text: '1.08');
  String? _result;
  bool _isCalculated  = false;

  @override
  void dispose() {
    _symbolCtrl.dispose();
    _lotCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final lot    = double.tryParse(_lotCtrl.text) ?? 0;
    final rate   = double.tryParse(_rateCtrl.text) ?? 1;
    final symbol = _symbolCtrl.text.toUpperCase();

    // Contract size: معمولاً 100,000 برای فارکس
    const contractSize = 100000.0;
    // Pip size
    final pipSize = symbol.contains('JPY') ? 0.01 : 0.0001;

    // Pip Value = (pipSize / exchange rate) × lot × contractSize
    final pipValue = (pipSize / rate) * lot * contractSize;

    setState(() {
      _result = '\$${pipValue.toStringAsFixed(2)}';
      _isCalculated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CalcField(
          controller: _symbolCtrl,
          label: lang == 'fa' ? 'جفت ارز' : 'Currency Pair',
          hint: 'EURUSD',
          prefix: Icon(Icons.currency_exchange,
              color: AppTheme.primary, size: 18.sp),
        ),
        SizedBox(height: 12.h),
        _CalcField(
          controller: _lotCtrl,
          label: lang == 'fa' ? 'سایز لات' : 'Lot Size',
          hint: '1.00',
          prefix: Icon(Icons.bar_chart, color: AppTheme.primary, size: 18.sp),
        ),
        SizedBox(height: 12.h),
        _CalcField(
          controller: _rateCtrl,
          label: lang == 'fa' ? 'نرخ ارز' : 'Exchange Rate',
          hint: '1.08',
          prefix: Icon(Icons.swap_horiz, color: AppTheme.primary, size: 18.sp),
        ),
        SizedBox(height: 20.h),
        ElevatedButton.icon(
          onPressed: _calculate,
          icon: Icon(Icons.calculate_rounded, size: 18.sp),
          label: Text(lang == 'fa' ? 'محاسبه' : 'Calculate'),
        ),
        if (_isCalculated && _result != null) ...[
          SizedBox(height: 20.h),
          _ResultCard(
            label: lang == 'fa' ? 'ارزش هر پیپ' : 'Pip Value per Pip',
            value: _result!,
            isNeutral: true,
          ),
          SizedBox(height: 8.h),
          Text(
            lang == 'fa'
                ? '* فرمول: (Pip / نرخ) × لات × 100,000'
                : '* Formula: (Pip / Rate) × Lot × 100,000',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppTheme.textSec(context), fontSize: 10.sp),
          ),
        ],
      ],
    );
  }
}

// ── ۲. Position Size Calculator ───────────────────────────────────────────────

class _PositionSizeCalculator extends StatefulWidget {
  final String lang;
  const _PositionSizeCalculator({super.key, required this.lang});

  @override
  State<_PositionSizeCalculator> createState() =>
      _PositionSizeCalculatorState();
}

class _PositionSizeCalculatorState extends State<_PositionSizeCalculator> {
  final _balanceCtrl  = TextEditingController(text: '10000');
  final _riskCtrl     = TextEditingController(text: '1');
  final _slCtrl       = TextEditingController(text: '50');
  final _pipValCtrl   = TextEditingController(text: '10');
  String? _result;
  bool _isCalculated  = false;

  @override
  void dispose() {
    _balanceCtrl.dispose();
    _riskCtrl.dispose();
    _slCtrl.dispose();
    _pipValCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final balance  = double.tryParse(_balanceCtrl.text) ?? 0;
    final riskPct  = double.tryParse(_riskCtrl.text) ?? 0;
    final sl       = double.tryParse(_slCtrl.text) ?? 1;
    final pipVal   = double.tryParse(_pipValCtrl.text) ?? 10;

    if (sl == 0 || pipVal == 0) return;

    // Lot = (Balance × Risk%) / (SL pips × pip value per lot)
    final riskAmount = balance * (riskPct / 100);
    final lot        = riskAmount / (sl * pipVal);

    setState(() {
      _result       = lot.toStringAsFixed(2);
      _isCalculated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CalcField(
          controller: _balanceCtrl,
          label: lang == 'fa' ? 'موجودی حساب (\$)' : 'Account Balance (\$)',
          hint: '10000',
          prefix: Icon(Icons.account_balance_wallet,
              color: AppTheme.primary, size: 18.sp),
        ),
        SizedBox(height: 12.h),
        _CalcField(
          controller: _riskCtrl,
          label: lang == 'fa' ? 'ریسک (%)' : 'Risk (%)',
          hint: '1',
          prefix: Icon(Icons.percent, color: AppTheme.primary, size: 18.sp),
        ),
        SizedBox(height: 12.h),
        _CalcField(
          controller: _slCtrl,
          label: lang == 'fa' ? 'حد ضرر (پیپ)' : 'Stop Loss (pips)',
          hint: '50',
          prefix: Icon(Icons.stop_circle_outlined,
              color: AppTheme.red, size: 18.sp),
        ),
        SizedBox(height: 12.h),
        _CalcField(
          controller: _pipValCtrl,
          label: lang == 'fa' ? 'ارزش هر پیپ (\$)' : 'Pip Value per Lot (\$)',
          hint: '10',
          prefix: Icon(Icons.attach_money,
              color: AppTheme.green, size: 18.sp),
        ),
        SizedBox(height: 20.h),
        ElevatedButton.icon(
          onPressed: _calculate,
          icon: Icon(Icons.calculate_rounded, size: 18.sp),
          label: Text(lang == 'fa' ? 'محاسبه' : 'Calculate'),
        ),
        if (_isCalculated && _result != null) ...[
          SizedBox(height: 20.h),
          _ResultCard(
            label: lang == 'fa' ? 'سایز لات پیشنهادی' : 'Suggested Lot Size',
            value: '$_result lots',
            isNeutral: true,
          ),
          SizedBox(height: 8.h),
          Text(
            lang == 'fa'
                ? '* فرمول: (موجودی × ریسک%) / (SL × ارزش پیپ)'
                : '* Formula: (Balance × Risk%) / (SL × Pip Value)',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppTheme.textSec(context), fontSize: 10.sp),
          ),
        ],
      ],
    );
  }
}

// ── ۳. P&L Calculator ────────────────────────────────────────────────────────

class _PnLCalculator extends StatefulWidget {
  final String lang;
  const _PnLCalculator({super.key, required this.lang});

  @override
  State<_PnLCalculator> createState() => _PnLCalculatorState();
}

class _PnLCalculatorState extends State<_PnLCalculator> {
  final _entryCtrl = TextEditingController(text: '1.0800');
  final _exitCtrl  = TextEditingController(text: '1.0850');
  final _lotCtrl   = TextEditingController(text: '1.00');
  String _tradeType = 'buy';
  double? _pnl;
  bool _isCalculated = false;

  @override
  void dispose() {
    _entryCtrl.dispose();
    _exitCtrl.dispose();
    _lotCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final entry = double.tryParse(_entryCtrl.text) ?? 0;
    final exit  = double.tryParse(_exitCtrl.text) ?? 0;
    final lot   = double.tryParse(_lotCtrl.text) ?? 0;

    final diff = _tradeType == 'buy' ? exit - entry : entry - exit;
    // فرض: pip size = 0.0001, contract = 100,000
    final pips  = diff / 0.0001;
    final pnl   = pips * 10.0 * lot;

    setState(() {
      _pnl          = pnl;
      _isCalculated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang     = widget.lang;
    final isBuy    = _tradeType == 'buy';
    final isProfit = (_pnl ?? 0) >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Buy / Sell toggle
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tradeType = 'buy'),
                child: AnimatedContainer(
                  duration: 200.ms,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    color: isBuy
                        ? AppTheme.green.withOpacity(0.15)
                        : AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: isBuy ? AppTheme.green : AppTheme.border(context),
                      width: isBuy ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    lang == 'fa' ? '📈 خرید' : '📈 Buy',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isBuy
                          ? AppTheme.green
                          : AppTheme.textSec(context),
                      fontSize: 14.sp,
                      fontWeight: isBuy ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tradeType = 'sell'),
                child: AnimatedContainer(
                  duration: 200.ms,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    color: !isBuy
                        ? AppTheme.red.withOpacity(0.15)
                        : AppTheme.surface(context),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: !isBuy ? AppTheme.red : AppTheme.border(context),
                      width: !isBuy ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    lang == 'fa' ? '📉 فروش' : '📉 Sell',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: !isBuy
                          ? AppTheme.red
                          : AppTheme.textSec(context),
                      fontSize: 14.sp,
                      fontWeight: !isBuy ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 14.h),

        _CalcField(
          controller: _entryCtrl,
          label: lang == 'fa' ? 'قیمت ورود' : 'Entry Price',
          hint: '1.0800',
          prefix: Icon(Icons.login, color: AppTheme.primary, size: 18.sp),
        ),
        SizedBox(height: 12.h),
        _CalcField(
          controller: _exitCtrl,
          label: lang == 'fa' ? 'قیمت خروج' : 'Exit Price',
          hint: '1.0850',
          prefix: Icon(Icons.logout, color: AppTheme.primary, size: 18.sp),
        ),
        SizedBox(height: 12.h),
        _CalcField(
          controller: _lotCtrl,
          label: lang == 'fa' ? 'سایز لات' : 'Lot Size',
          hint: '1.00',
          prefix: Icon(Icons.bar_chart, color: AppTheme.primary, size: 18.sp),
        ),
        SizedBox(height: 20.h),

        ElevatedButton.icon(
          onPressed: _calculate,
          icon: Icon(Icons.calculate_rounded, size: 18.sp),
          label: Text(lang == 'fa' ? 'محاسبه' : 'Calculate'),
        ),

        if (_isCalculated && _pnl != null) ...[
          SizedBox(height: 20.h),
          _ResultCard(
            label: lang == 'fa' ? 'سود / ضرر' : 'Profit / Loss',
            value: '${_pnl! >= 0 ? '+' : ''}\$${_pnl!.toStringAsFixed(2)}',
            isPositive: isProfit,
          ),
        ],
      ],
    );
  }
}
