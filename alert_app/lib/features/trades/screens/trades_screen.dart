import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/trade_provider.dart';
import '../../../core/models/trade_model.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/shimmer_widgets.dart';

class TradesScreen extends StatefulWidget {
  const TradesScreen({super.key});
  @override
  State<TradesScreen> createState() => _TradesScreenState();
}

class _TradesScreenState extends State<TradesScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _showOpen = true; // toggle open/closed

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lang   = context.watch<LocaleProvider>().lang;
    final isDark = context.watch<ThemeProvider>().isDark;
    final prov   = context.watch<TradeProvider>();
    final trades = _showOpen ? prov.openTrades : prov.closedTrades;

    return Directionality(
      textDirection: lang == 'fa' ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
        body: RefreshIndicator(
          onRefresh: () async => setState(() {}),
          color: AppTheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [

              // ── Header ────────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 195.h,
                floating: false, pinned: true,
                backgroundColor: Colors.transparent, elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: _TradesHeader(
                    lang: lang, isDark: isDark, prov: prov,
                  ),
                ),
              ),

              // ── Toggle ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                  child: _ToggleSwitch(
                    lang: lang, isDark: isDark,
                    showOpen: _showOpen,
                    openCount:   prov.openTrades.length,
                    closedCount: prov.closedTrades.length,
                    onToggle: (v) => setState(() => _showOpen = v),
                  ),
                ),
              ),

              // ── Trade list ────────────────────────────────────────────
              if (prov.loading)
                SliverPadding(
                  padding: EdgeInsets.only(bottom: 120.h),
                  sliver: SliverList(delegate: SliverChildBuilderDelegate(
                    (_, __) => const ShimmerAlertTile(), childCount: 4,
                  )),
                )
              else if (trades.isEmpty)
                SliverFillRemaining(
                  child: _EmptyTrades(
                    lang: lang, isDark: isDark, isOpen: _showOpen,
                    onAdd: () => _showAddSheet(context, lang, isDark),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 120.h),
                  sliver: SliverList(delegate: SliverChildBuilderDelegate(
                    (_, i) => _TradeCard(
                      trade:  trades[i],
                      lang:   lang,
                      isDark: isDark,
                      index:  i,
                      onDelete: () => prov.deleteTrade(trades[i].id),
                    ),
                    childCount: trades.length,
                  )),
                ),
            ],
          ),
        ),
        floatingActionButton: _AddTradeFab(
          lang: lang, isDark: isDark,
          onTap: () => _showAddSheet(context, lang, isDark),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  void _showAddSheet(BuildContext ctx, String lang, bool isDark) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddTradeSheet(lang: lang, isDark: isDark),
    );
  }
}

// ── Header with stats ─────────────────────────────────────────────────────────

class _TradesHeader extends StatelessWidget {
  const _TradesHeader({required this.lang, required this.isDark, required this.prov});
  final String lang;
  final bool   isDark;
  final TradeProvider prov;

  Color get _pnlColor => prov.totalPnl >= 0
      ? AppTheme.green : AppTheme.red;

  @override
  Widget build(BuildContext context) {
    final winRate = prov.winRate;
    final pnl     = prov.totalPnl;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: pnl >= 0
              ? [const Color(0xFF00695C), const Color(0xFF00C853), const Color(0xFF64DD17)]
              : [const Color(0xFFB71C1C), const Color(0xFFFF5252), const Color(0xFFFF8A65)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                lang == 'fa' ? 'دفتر معاملات' : 'Trade Journal',
                style: TextStyle(
                  fontSize: 24.sp, fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 10.h),

              // Stats row
              Row(children: [
                _StatBadge(
                  label: lang == 'fa' ? 'سود/زیان' : 'Total P&L',
                  value: '${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(1)}',
                  icon:  Icons.trending_up_rounded,
                ),
                SizedBox(width: 10.w),
                _StatBadge(
                  label: lang == 'fa' ? 'نرخ برد' : 'Win Rate',
                  value: '${winRate.toStringAsFixed(0)}%',
                  icon:  Icons.pie_chart_outline_rounded,
                ),
                SizedBox(width: 10.w),
                _StatBadge(
                  label: lang == 'fa' ? 'معاملات' : 'Total',
                  value: '${prov.trades.length}',
                  icon:  Icons.receipt_long_outlined,
                ),
              ]),
              SizedBox(height: 8.h),

              // Win rate bar
              if (prov.closedTrades.isNotEmpty) ...[
                Text(
                  lang == 'fa'
                      ? '${winRate.toStringAsFixed(0)}% موفقیت در ${prov.closedTrades.length} معامله'
                      : '${winRate.toStringAsFixed(0)}% win rate across ${prov.closedTrades.length} trades',
                  style: TextStyle(fontSize: 11.sp, color: Colors.white70),
                ),
                SizedBox(height: 4.h),
                Container(
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (winRate / 100).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                    ).animate().scaleX(
                        begin: 0, end: 1,
                        alignment: Alignment.centerLeft,
                        duration: 800.ms, curve: Curves.easeOut),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.label, required this.value, required this.icon});
  final String label, value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11.sp, color: Colors.white70),
          SizedBox(width: 3.w),
          Text(label, style: TextStyle(fontSize: 9.sp, color: Colors.white70)),
        ]),
        SizedBox(height: 2.h),
        Text(value, style: TextStyle(
          fontSize: 13.sp, fontWeight: FontWeight.bold,
          color: Colors.white, fontFamily: 'TexGyreAdventor',
        )),
      ]),
    );
  }
}

// ── Toggle switch ─────────────────────────────────────────────────────────────

class _ToggleSwitch extends StatelessWidget {
  const _ToggleSwitch({
    required this.lang, required this.isDark, required this.showOpen,
    required this.openCount, required this.closedCount, required this.onToggle,
  });
  final String lang;
  final bool isDark, showOpen;
  final int openCount, closedCount;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42.h,
      decoration: BoxDecoration(
        color:        isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14.r),
      ),
      padding: EdgeInsets.all(3.r),
      child: Row(children: [
        _ToggleBtn(
          label: '${lang == 'fa' ? 'باز' : 'Open'} ($openCount)',
          active: showOpen,
          isDark: isDark,
          onTap:  () => onToggle(true),
        ),
        SizedBox(width: 3.w),
        _ToggleBtn(
          label: '${lang == 'fa' ? 'بسته' : 'Closed'} ($closedCount)',
          active: !showOpen,
          isDark: isDark,
          onTap:  () => onToggle(false),
        ),
      ]),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn({required this.label, required this.active,
      required this.isDark, required this.onTap});
  final String label;
  final bool active, isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: double.infinity,
          decoration: BoxDecoration(
            color: active
                ? (isDark ? AppTheme.darkCard : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11.r),
            boxShadow: active ? [
              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)
            ] : null,
          ),
          child: Center(child: Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
          )),
        ),
      ),
    );
  }
}

// ── Trade card ────────────────────────────────────────────────────────────────

class _TradeCard extends StatelessWidget {
  const _TradeCard({
    super.key, required this.trade, required this.lang,
    required this.isDark, required this.index, required this.onDelete,
  });
  final TradeModel   trade;
  final String       lang;
  final bool         isDark;
  final int          index;
  final VoidCallback onDelete;

  bool   get _isBuy  => trade.isBuy;
  Color  get _color  => _isBuy ? AppTheme.green : AppTheme.red;
  double? get _pnl   => trade.pnl;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key:       ValueKey('t_${trade.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          color: AppTheme.red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20.r),
        ),
        alignment: Alignment.centerRight,
        padding:   EdgeInsets.only(right: 24.w),
        child: Icon(Icons.delete_outline_rounded, color: AppTheme.red, size: 24.sp),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: _color.withOpacity(0.2)),
                boxShadow: [BoxShadow(
                  color: _color.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3),
                )],
              ),
              child: Column(children: [
                Row(children: [
                  // Buy/Sell badge
                  Container(
                    width: 44.w, height: 44.w,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_color.withOpacity(0.2), _color.withOpacity(0.05)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: _color.withOpacity(0.3)),
                    ),
                    child: Icon(
                      _isBuy ? Icons.call_made_rounded : Icons.call_received_rounded,
                      color: _color, size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trade.symbol,
                        style: TextStyle(
                          fontSize: 17.sp, fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                          fontFamily: 'TexGyreAdventor',
                        ),
                      ),
                      Text(
                        '${_isBuy ? (lang=='fa'?'خرید':'BUY') : (lang=='fa'?'فروش':'SELL')} • ${lang=='fa'?'ورود:':'Entry:'} ${trade.entry}',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  )),
                  // P&L
                  if (_pnl != null)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: (_pnl! >= 0 ? AppTheme.green : AppTheme.red).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Text(
                        '${_pnl! >= 0 ? '+' : ''}${_pnl!.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 14.sp, fontWeight: FontWeight.bold,
                          color: _pnl! >= 0 ? AppTheme.green : AppTheme.red,
                          fontFamily: 'TexGyreAdventor',
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        lang == 'fa' ? 'باز' : 'Open',
                        style: TextStyle(fontSize: 11.sp, color: AppTheme.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ]),

                if (trade.notes != null && trade.notes!.isNotEmpty) ...[
                  SizedBox(height: 10.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      trade.notes!,
                      style: TextStyle(
                        fontSize: 11.sp, fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],

                SizedBox(height: 8.h),
                Row(children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 10.sp, color: isDark ? Colors.white30 : Colors.black26),
                  SizedBox(width: 3.w),
                  Text(
                    trade.openedAt.toString().substring(0, 10),
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: isDark ? Colors.white30 : Colors.black26,
                      fontFamily: 'TexGyreAdventor',
                    ),
                  ),
                  const Spacer(),
                  if (trade.lotSize > 0) ...[
                    Text(
                      'Lot: ${trade.lotSize}',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: isDark ? Colors.white30 : Colors.black26,
                        fontFamily: 'TexGyreAdventor',
                      ),
                    ),
                  ],
                ]),
              ]),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (index * 60).ms, duration: 300.ms)
        .slideX(begin: 0.05, end: 0);
  }
}

// ── Add Trade Bottom Sheet ────────────────────────────────────────────────────

class _AddTradeSheet extends StatefulWidget {
  const _AddTradeSheet({required this.lang, required this.isDark});
  final String lang;
  final bool   isDark;

  @override
  State<_AddTradeSheet> createState() => _AddTradeSheetState();
}

class _AddTradeSheetState extends State<_AddTradeSheet> {
  final _symCtrl   = TextEditingController();
  final _entryCtrl = TextEditingController();
  final _exitCtrl  = TextEditingController();
  final _lotCtrl   = TextEditingController(text: '0.1');
  final _slCtrl    = TextEditingController();
  final _tpCtrl    = TextEditingController();
  final _noteCtrl  = TextEditingController();
  bool   _isBuy    = true;
  bool   _loading  = false;
  File?  _image;

  @override
  void dispose() {
    for (final c in [_symCtrl, _entryCtrl, _exitCtrl, _lotCtrl, _slCtrl, _tpCtrl, _noteCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_symCtrl.text.isEmpty || _entryCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      await context.read<TradeProvider>().addTrade(
        symbol:     _symCtrl.text.trim().toUpperCase(),
        type:       _isBuy ? 'buy' : 'sell',
        entry:      double.tryParse(_entryCtrl.text) ?? 0,
        exit:       double.tryParse(_exitCtrl.text),
        lotSize:    double.tryParse(_lotCtrl.text) ?? 0.1,
        stopLoss:   double.tryParse(_slCtrl.text),
        takeProfit: double.tryParse(_tpCtrl.text),
        notes:      _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        imageFile:  _image,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang   = widget.lang;
    final isDark = widget.isDark;

    return Container(
      margin: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
      padding: EdgeInsets.fromLTRB(
          20.w, 20.h, 20.w, MediaQuery.of(context).viewInsets.bottom + 20.h),
      decoration: BoxDecoration(
        color:        isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(28.r),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
              width: 36.w, height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2.r),
              ),
            )),
            SizedBox(height: 14.h),

            Text(
              lang == 'fa' ? '📊 معامله جدید' : '📊 New Trade',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87),
            ),
            SizedBox(height: 14.h),

            // Buy / Sell toggle
            Container(
              height: 42.h,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14.r),
              ),
              padding: EdgeInsets.all(3.r),
              child: Row(children: [
                _SheetToggleBtn(
                  label: lang == 'fa' ? 'خرید ↑' : 'BUY ↑',
                  active: _isBuy, color: AppTheme.green,
                  onTap:  () => setState(() => _isBuy = true),
                ),
                SizedBox(width: 3.w),
                _SheetToggleBtn(
                  label: lang == 'fa' ? 'فروش ↓' : 'SELL ↓',
                  active: !_isBuy, color: AppTheme.red,
                  onTap:  () => setState(() => _isBuy = false),
                ),
              ]),
            ),
            SizedBox(height: 12.h),

            _SheetField(ctrl: _symCtrl, hint: lang=='fa'?'نماد (مثال: XAUUSD)':'Symbol (e.g. XAUUSD)',
                icon: Icons.candlestick_chart_outlined, isDark: isDark, caps: true),
            SizedBox(height: 8.h),
            Row(children: [
              Expanded(child: _SheetField(ctrl: _entryCtrl,
                  hint: lang=='fa'?'قیمت ورود':'Entry', icon: Icons.login_rounded,
                  isDark: isDark, numeric: true)),
              SizedBox(width: 8.w),
              Expanded(child: _SheetField(ctrl: _exitCtrl,
                  hint: lang=='fa'?'قیمت خروج':'Exit', icon: Icons.logout_rounded,
                  isDark: isDark, numeric: true)),
            ]),
            SizedBox(height: 8.h),
            Row(children: [
              Expanded(child: _SheetField(ctrl: _lotCtrl, hint: 'Lot',
                  icon: Icons.tune_rounded, isDark: isDark, numeric: true)),
              SizedBox(width: 8.w),
              Expanded(child: _SheetField(ctrl: _slCtrl,
                  hint: lang=='fa'?'حد ضرر':'Stop Loss',
                  icon: Icons.shield_outlined, isDark: isDark, numeric: true)),
              SizedBox(width: 8.w),
              Expanded(child: _SheetField(ctrl: _tpCtrl,
                  hint: lang=='fa'?'هدف':'Take Profit',
                  icon: Icons.flag_outlined, isDark: isDark, numeric: true)),
            ]),
            SizedBox(height: 8.h),
            _SheetField(ctrl: _noteCtrl,
                hint: lang=='fa'?'یادداشت (اختیاری)':'Notes (optional)',
                icon: Icons.notes_rounded, isDark: isDark),
            SizedBox(height: 14.h),

            SizedBox(
              width: double.infinity, height: 52.h,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor:     Colors.transparent,
                  padding:         EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r)),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: _loading ? null : LinearGradient(
                      colors: _isBuy
                          ? [const Color(0xFF00695C), AppTheme.green]
                          : [const Color(0xFFB71C1C), AppTheme.red],
                      begin: Alignment.centerLeft, end: Alignment.centerRight,
                    ),
                    color:  _loading ? (isDark ? Colors.white12 : Colors.black12) : null,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    child: _loading
                        ? SizedBox(width: 20.w, height: 20.w,
                            child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            lang == 'fa' ? 'ثبت معامله' : 'Save Trade',
                            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetToggleBtn extends StatelessWidget {
  const _SheetToggleBtn({required this.label, required this.active,
      required this.color, required this.onTap});
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: double.infinity,
          decoration: BoxDecoration(
            color:        active ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(11.r),
            border:       active ? Border.all(color: color.withOpacity(0.4)) : null,
          ),
          child: Center(child: Text(
            label,
            style: TextStyle(
              fontSize: 13.sp, fontWeight: FontWeight.w700,
              color: active ? color : color.withOpacity(0.4),
            ),
          )),
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({required this.ctrl, required this.hint,
      required this.icon, required this.isDark,
      this.numeric = false, this.caps = false});
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final bool isDark, numeric, caps;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      textCapitalization: caps ? TextCapitalization.characters : TextCapitalization.none,
      textDirection: TextDirection.ltr,
      style: TextStyle(fontSize: 13.sp, color: isDark ? Colors.white : Colors.black87,
          fontFamily: 'TexGyreAdventor'),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black26, fontSize: 12.sp),
        prefixIcon: Icon(icon, color: AppTheme.primary, size: 16.sp),
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(color: AppTheme.primary, width: 1.5)),
        contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 10.w),
        isDense: true,
      ),
    );
  }
}

// ── FAB ───────────────────────────────────────────────────────────────────────

class _AddTradeFab extends StatelessWidget {
  const _AddTradeFab({required this.lang, required this.isDark, required this.onTap});
  final String lang;
  final bool   isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 78.h),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52.h,
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A42CC), Color(0xFF6C63FF), Color(0xFF00B4D8)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26.r),
            boxShadow: [BoxShadow(
              color: AppTheme.primary.withOpacity(0.4),
              blurRadius: 16, offset: const Offset(0, 6),
            )],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 20.sp),
            SizedBox(width: 6.w),
            Text(lang == 'fa' ? 'معامله جدید' : 'New Trade',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.white)),
          ]),
        ).animate().scale(duration: 200.ms, curve: Curves.elasticOut),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyTrades extends StatelessWidget {
  const _EmptyTrades({required this.lang, required this.isDark,
      required this.isOpen, required this.onAdd});
  final String lang;
  final bool isDark, isOpen;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 90.w, height: 90.w,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary.withOpacity(0.15), AppTheme.accent.withOpacity(0.1)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.receipt_long_outlined,
              size: 44.sp, color: AppTheme.primary.withOpacity(0.6)),
        ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
        SizedBox(height: 16.h),
        Text(
          isOpen
              ? (lang == 'fa' ? 'هیچ معامله بازی نداری' : 'No open trades')
              : (lang == 'fa' ? 'هیچ معامله بسته‌ای نداری' : 'No closed trades'),
          style: TextStyle(
            fontSize: 16.sp, fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        SizedBox(height: 20.h),
        GestureDetector(
          onTap: onAdd,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 14.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4A42CC), Color(0xFF6C63FF)],
                begin: Alignment.centerLeft, end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [BoxShadow(
                color: AppTheme.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4),
              )],
            ),
            child: Text(
              lang == 'fa' ? 'ثبت اولین معامله' : 'Log first trade',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ).animate().fadeIn(delay: 200.ms),
      ],
    );
  }
}
