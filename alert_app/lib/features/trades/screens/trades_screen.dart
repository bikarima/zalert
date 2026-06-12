import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/models/trade_model.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';

class TradesScreen extends StatefulWidget {
  const TradesScreen({super.key});

  @override
  State<TradesScreen> createState() => _TradesScreenState();
}

class _TradesScreenState extends State<TradesScreen> {
  List<TradeModel> _trades = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTrades();
  }

  Future<void> _loadTrades() async {
    final json = await StorageService.instance.getTradesJson();
    if (json != null && json.isNotEmpty) {
      try {
        setState(() {
          _trades  = TradeModel.listFromJson(json);
          _loading = false;
        });
        return;
      } catch (_) {}
    }
    setState(() => _loading = false);
  }

  Future<void> _saveTrades() async {
    await StorageService.instance.saveTradesJson(
      TradeModel.listToJson(_trades),
    );
  }

  void _openAddForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TradeForm(
        lang: context.read<LocaleProvider>().lang,
        onSave: (trade) {
          setState(() => _trades.insert(0, trade));
          _saveTrades();
        },
      ),
    );
  }

  void _closeTrade(TradeModel trade) {
    showDialog(
      context: context,
      builder: (ctx) {
        final exitCtrl = TextEditingController();
        final lang = context.read<LocaleProvider>().lang;
        return AlertDialog(
          backgroundColor: AppTheme.card(context),
          title: Text(
            lang == 'fa' ? 'بستن پوزیشن' : 'Close Position',
            style: TextStyle(
                color: AppTheme.text(context), fontSize: 16.sp),
          ),
          content: TextField(
            controller: exitCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: lang == 'fa' ? 'قیمت خروج' : 'Exit Price',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(lang == 'fa' ? 'انصراف' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final exit = double.tryParse(exitCtrl.text);
                if (exit != null) {
                  setState(() {
                    final idx = _trades.indexWhere((t) => t.id == trade.id);
                    if (idx >= 0) {
                      _trades[idx] = trade.copyWith(
                        exit: exit,
                        closedAt: DateTime.now(),
                      );
                    }
                  });
                  _saveTrades();
                  Navigator.pop(ctx);
                }
              },
              child: Text(lang == 'fa' ? 'ثبت' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteTrade(String id) {
    setState(() => _trades.removeWhere((t) => t.id == id));
    _saveTrades();
  }

  @override
  Widget build(BuildContext context) {
    final lang  = context.watch<LocaleProvider>().lang;
    final isRtl = lang == 'fa';

    // آمار کلی
    final closedTrades = _trades.where((t) => t.isClosed).toList();
    final totalPnl     = closedTrades.fold(
      0.0, (sum, t) => sum + (t.pnl ?? 0));
    final wins         = closedTrades.where((t) => t.isWin).length;
    final winRate      = closedTrades.isEmpty
        ? 0.0
        : (wins / closedTrades.length) * 100;

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
                lang == 'fa' ? 'معاملات من' : 'My Trades',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                    color: AppTheme.text(context)),
              ),
            ),

            if (!_loading) ...[
              // خلاصه آمار
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: _SummaryCards(
                    totalPnl:  totalPnl,
                    winRate:   winRate,
                    tradeCount: _trades.length,
                    lang: lang,
                  ),
                ),
              ),

              if (_trades.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 56.sp,
                            color: AppTheme.textSec(context)),
                        SizedBox(height: 12.h),
                        Text(
                          lang == 'fa'
                              ? 'هیچ معامله‌ای ثبت نشده'
                              : 'No trades recorded yet',
                          style: TextStyle(
                              color: AppTheme.textSec(context),
                              fontSize: 14.sp),
                        ),
                      ],
                    ).animate().fadeIn(duration: 400.ms),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _TradeCard(
                      trade: _trades[i],
                      lang: lang,
                      onClose: _trades[i].isClosed
                          ? null
                          : () => _closeTrade(_trades[i]),
                      onDelete: () => _deleteTrade(_trades[i].id),
                    ).animate().fadeIn(
                        duration: 300.ms,
                        delay: Duration(milliseconds: i * 50)),
                    childCount: _trades.length,
                  ),
                ),

              SliverToBoxAdapter(child: SizedBox(height: 90.h)),
            ] else
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openAddForm,
          icon: Icon(Icons.add_rounded, size: 20.sp),
          label: Text(
            lang == 'fa' ? 'معامله جدید' : 'New Trade',
            style: TextStyle(fontSize: 13.sp),
          ),
          backgroundColor: AppTheme.primary,
        ).animate().scale(duration: 300.ms, curve: Curves.elasticOut),
      ),
    );
  }
}

// ── Summary Cards ─────────────────────────────────────────────────────────────

class _SummaryCards extends StatelessWidget {
  final double totalPnl;
  final double winRate;
  final int tradeCount;
  final String lang;

  const _SummaryCards({
    required this.totalPnl,
    required this.winRate,
    required this.tradeCount,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final isPnlPositive = totalPnl >= 0;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: lang == 'fa' ? 'کل سود/ضرر' : 'Total P&L',
            value:
                '${isPnlPositive ? '+' : ''}\$${totalPnl.toStringAsFixed(2)}',
            color: isPnlPositive ? AppTheme.green : AppTheme.red,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _StatCard(
            label: lang == 'fa' ? 'نرخ برد' : 'Win Rate',
            value: '${winRate.toStringAsFixed(1)}%',
            color: AppTheme.primary,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _StatCard(
            label: lang == 'fa' ? 'معاملات' : 'Trades',
            value: '$tradeCount',
            color: AppTheme.orange,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label, required this.value, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color, fontSize: 16.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textSec(context), fontSize: 10.sp),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Trade Card ────────────────────────────────────────────────────────────────

class _TradeCard extends StatelessWidget {
  final TradeModel trade;
  final String lang;
  final VoidCallback? onClose;
  final VoidCallback onDelete;

  const _TradeCard({
    required this.trade,
    required this.lang,
    required this.onClose,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isBuy = trade.type == 'buy';
    final typeColor = isBuy ? AppTheme.green : AppTheme.red;
    final pnl = trade.pnl;
    final isPnlPositive = (pnl ?? 0) >= 0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppTheme.border(context)),
        ),
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Symbol badge
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      trade.symbol,
                      style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // Buy/Sell badge
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      isBuy
                          ? (lang == 'fa' ? 'خرید' : 'BUY')
                          : (lang == 'fa' ? 'فروش' : 'SELL'),
                      style: TextStyle(
                          color: typeColor,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  // P&L
                  if (pnl != null)
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: (isPnlPositive ? AppTheme.green : AppTheme.red)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: (isPnlPositive
                                  ? AppTheme.green
                                  : AppTheme.red)
                              .withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '${isPnlPositive ? '+' : ''}\$${pnl.toStringAsFixed(2)}',
                        style: TextStyle(
                            color: isPnlPositive
                                ? AppTheme.green
                                : AppTheme.red,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold),
                      ),
                    )
                  else
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: AppTheme.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        lang == 'fa' ? 'باز' : 'Open',
                        style: TextStyle(
                            color: AppTheme.orange, fontSize: 11.sp),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  _InfoChip(
                    label: lang == 'fa' ? 'ورود' : 'Entry',
                    value: trade.entry.toString(),
                    context: context,
                  ),
                  SizedBox(width: 8.w),
                  if (trade.exit != null)
                    _InfoChip(
                      label: lang == 'fa' ? 'خروج' : 'Exit',
                      value: trade.exit!.toString(),
                      context: context,
                    ),
                  SizedBox(width: 8.w),
                  _InfoChip(
                    label: lang == 'fa' ? 'لات' : 'Lot',
                    value: trade.lotSize.toString(),
                    context: context,
                  ),
                ],
              ),
              if (trade.notes != null && trade.notes!.isNotEmpty) ...[
                SizedBox(height: 8.h),
                Text(
                  trade.notes!,
                  style: TextStyle(
                      color: AppTheme.textSec(context), fontSize: 11.sp),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              SizedBox(height: 8.h),
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 11.sp, color: AppTheme.textSec(context)),
                  SizedBox(width: 4.w),
                  Text(
                    _formatDate(trade.openedAt),
                    style: TextStyle(
                        color: AppTheme.textSec(context), fontSize: 10.sp),
                  ),
                  const Spacer(),
                  if (onClose != null)
                    TextButton(
                      onPressed: onClose,
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: EdgeInsets.symmetric(
                            horizontal: 10.w, vertical: 4.h),
                        foregroundColor: AppTheme.primary,
                      ),
                      child: Text(
                        lang == 'fa' ? 'بستن' : 'Close',
                        style: TextStyle(fontSize: 11.sp),
                      ),
                    ),
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline,
                        size: 16.sp, color: AppTheme.red),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.all(4.w),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/'
        '${d.day.toString().padLeft(2, '0')}';
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final BuildContext context;

  const _InfoChip({
    required this.label, required this.value, required this.context,
  });

  @override
  Widget build(BuildContext ctx) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppTheme.surface(ctx),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppTheme.border(ctx)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: AppTheme.text(ctx), fontSize: 11.sp),
      ),
    );
  }
}

// ── Trade Form (Bottom Sheet) ─────────────────────────────────────────────────

class _TradeForm extends StatefulWidget {
  final String lang;
  final Function(TradeModel) onSave;

  const _TradeForm({required this.lang, required this.onSave});

  @override
  State<_TradeForm> createState() => _TradeFormState();
}

class _TradeFormState extends State<_TradeForm> {
  final _formKey    = GlobalKey<FormState>();
  final _symbolCtrl = TextEditingController();
  final _entryCtrl  = TextEditingController();
  final _exitCtrl   = TextEditingController();
  final _lotCtrl    = TextEditingController(text: '0.01');
  final _notesCtrl  = TextEditingController();
  String _type = 'buy';

  @override
  void dispose() {
    _symbolCtrl.dispose();
    _entryCtrl.dispose();
    _exitCtrl.dispose();
    _lotCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    const uuid = Uuid();
    final trade = TradeModel(
      id:      uuid.v4(),
      symbol:  _symbolCtrl.text.trim().toUpperCase(),
      type:    _type,
      entry:   double.parse(_entryCtrl.text),
      exit:    _exitCtrl.text.trim().isNotEmpty
               ? double.tryParse(_exitCtrl.text)
               : null,
      lotSize: double.parse(_lotCtrl.text),
      notes:   _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      openedAt: DateTime.now(),
      closedAt: _exitCtrl.text.trim().isNotEmpty ? DateTime.now() : null,
    );
    widget.onSave(trade);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final lang  = widget.lang;
    final isBuy = _type == 'buy';

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40.w, height: 4.h,
                  decoration: BoxDecoration(
                    color: AppTheme.border(context),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                lang == 'fa' ? 'ثبت معامله جدید' : 'Record New Trade',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.text(context),
                    fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20.h),

              // Buy / Sell
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _type = 'buy'),
                      child: AnimatedContainer(
                        duration: 200.ms,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        decoration: BoxDecoration(
                          color: isBuy
                              ? AppTheme.green.withOpacity(0.15)
                              : AppTheme.surface(context),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                              color: isBuy
                                  ? AppTheme.green
                                  : AppTheme.border(context),
                              width: isBuy ? 2 : 1),
                        ),
                        child: Text(
                          lang == 'fa' ? '📈 خرید' : '📈 Buy',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: isBuy
                                  ? AppTheme.green
                                  : AppTheme.textSec(context),
                              fontSize: 14.sp,
                              fontWeight: isBuy
                                  ? FontWeight.bold
                                  : FontWeight.normal),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _type = 'sell'),
                      child: AnimatedContainer(
                        duration: 200.ms,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        decoration: BoxDecoration(
                          color: !isBuy
                              ? AppTheme.red.withOpacity(0.15)
                              : AppTheme.surface(context),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                              color: !isBuy
                                  ? AppTheme.red
                                  : AppTheme.border(context),
                              width: !isBuy ? 2 : 1),
                        ),
                        child: Text(
                          lang == 'fa' ? '📉 فروش' : '📉 Sell',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: !isBuy
                                  ? AppTheme.red
                                  : AppTheme.textSec(context),
                              fontSize: 14.sp,
                              fontWeight: !isBuy
                                  ? FontWeight.bold
                                  : FontWeight.normal),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),

              TextFormField(
                controller: _symbolCtrl,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(
                    color: AppTheme.text(context), fontSize: 14.sp),
                decoration: InputDecoration(
                  labelText: lang == 'fa' ? 'نماد' : 'Symbol',
                  hintText: 'EURUSD',
                  prefixIcon: Icon(Icons.currency_exchange,
                      color: AppTheme.primary, size: 18.sp),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? (lang == 'fa' ? 'نماد را وارد کنید' : 'Enter symbol')
                    : null,
              ),
              SizedBox(height: 12.h),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _entryCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                          color: AppTheme.text(context), fontSize: 14.sp),
                      decoration: InputDecoration(
                        labelText: lang == 'fa' ? 'ورود' : 'Entry',
                        prefixIcon: Icon(Icons.login,
                            color: AppTheme.primary, size: 18.sp),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return lang == 'fa' ? 'الزامی' : 'Required';
                        }
                        if (double.tryParse(v) == null) {
                          return lang == 'fa' ? 'عدد وارد کنید' : 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: TextFormField(
                      controller: _exitCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                          color: AppTheme.text(context), fontSize: 14.sp),
                      decoration: InputDecoration(
                        labelText: lang == 'fa'
                            ? 'خروج (اختیاری)'
                            : 'Exit (optional)',
                        prefixIcon: Icon(Icons.logout,
                            color: AppTheme.primary, size: 18.sp),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),

              TextFormField(
                controller: _lotCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textDirection: TextDirection.ltr,
                style: TextStyle(
                    color: AppTheme.text(context), fontSize: 14.sp),
                decoration: InputDecoration(
                  labelText: lang == 'fa' ? 'سایز لات' : 'Lot Size',
                  prefixIcon: Icon(Icons.bar_chart,
                      color: AppTheme.primary, size: 18.sp),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return lang == 'fa' ? 'الزامی' : 'Required';
                  }
                  if (double.tryParse(v) == null) {
                    return lang == 'fa' ? 'عدد وارد کنید' : 'Invalid';
                  }
                  return null;
                },
              ),
              SizedBox(height: 12.h),

              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                style: TextStyle(
                    color: AppTheme.text(context), fontSize: 14.sp),
                decoration: InputDecoration(
                  labelText: lang == 'fa'
                      ? 'یادداشت (اختیاری)'
                      : 'Notes (optional)',
                  prefixIcon: Icon(Icons.notes,
                      color: AppTheme.primary, size: 18.sp),
                ),
              ),
              SizedBox(height: 20.h),

              ElevatedButton.icon(
                onPressed: _save,
                icon: Icon(Icons.save_rounded, size: 18.sp),
                label: Text(lang == 'fa' ? 'ذخیره معامله' : 'Save Trade'),
              ),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
  }
}
