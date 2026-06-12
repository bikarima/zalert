import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/trade_provider.dart';
import '../../../core/models/trade_model.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/services/drive/google_drive_service.dart';
import '../../../core/theme/app_theme.dart';

class TradesScreen extends StatefulWidget {
  const TradesScreen({super.key});
  @override
  State<TradesScreen> createState() => _TradesScreenState();
}

class _TradesScreenState extends State<TradesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TradeProvider>();
    final lang     = context.watch<LocaleProvider>().lang;
    final isRtl    = lang == 'fa';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.bg(context),
        body: CustomScrollView(
          slivers: [
            // ── Header ─────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              expandedHeight: 130.h,
              backgroundColor: AppTheme.bg(context),
              flexibleSpace: FlexibleSpaceBar(
                background: _TradesHeader(provider: provider, lang: lang),
              ),
              title: Text(lang == 'fa' ? 'معاملات من' : 'My Trades',
                  style: TextStyle(
                      fontSize: 16.sp, fontWeight: FontWeight.bold)),
              actions: [
                // دکمه Google Drive login
                IconButton(
                  icon: Icon(
                    GoogleDriveService.instance.isSignedIn
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_outlined,
                    color: GoogleDriveService.instance.isSignedIn
                        ? AppTheme.green : AppTheme.textSec(context),
                    size: 20.sp,
                  ),
                  onPressed: () => _handleDriveAuth(context, lang),
                ),
              ],
              bottom: TabBar(
                controller: _tabs,
                tabs: [
                  Tab(text: lang == 'fa' ? 'باز' : 'Open'),
                  Tab(text: lang == 'fa' ? 'بسته' : 'Closed'),
                ],
              ),
            ),

            SliverFillRemaining(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _TradeList(
                    trades: provider.openTrades,
                    lang: lang,
                    isOpen: true,
                  ),
                  _TradeList(
                    trades: provider.closedTrades,
                    lang: lang,
                    isOpen: false,
                  ),
                ],
              ),
            ),
          ],
        ),

        // ── دکمه Enter Position ───────────────────────────────────
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.extended(
              onPressed: () => _showAddTradeSheet(context, lang),
              icon: Icon(Icons.add_chart_rounded, size: 20.sp),
              label: Text(
                lang == 'fa' ? 'ورود به معامله' : 'Enter Position',
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold),
              ),
              backgroundColor: AppTheme.green,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDriveAuth(BuildContext context, String lang) async {
    if (GoogleDriveService.instance.isSignedIn) {
      await GoogleDriveService.instance.signOut();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(lang == 'fa' ? 'از Google خارج شدید' : 'Signed out from Google'),
      ));
    } else {
      final ok = await GoogleDriveService.instance.signIn();
      setState(() {});
      if (ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lang == 'fa'
              ? 'وارد Google Drive شدید ✓'
              : 'Signed in to Google Drive ✓'),
          backgroundColor: AppTheme.green,
        ));
      }
    }
  }

  void _showAddTradeSheet(BuildContext context, String lang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddTradeSheet(lang: lang),
    );
  }
}

// ── Header آمار ──────────────────────────────────────────────────────────────

class _TradesHeader extends StatelessWidget {
  final TradeProvider provider;
  final String lang;
  const _TradesHeader({required this.provider, required this.lang});

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final totalPnl = provider.totalPnl;
    final pnlColor = totalPnl >= 0 ? AppTheme.green : AppTheme.red;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0D1A0D), const Color(0xFF0A0A14)]
              : [const Color(0xFFE8F5E9), const Color(0xFFF5F5FF)],
        ),
      ),
      padding: EdgeInsets.fromLTRB(16.w, 68.h, 16.w, 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatCard(
            label: lang == 'fa' ? 'باز' : 'Open',
            value: '${provider.openTrades.length}',
            color: AppTheme.blue,
            icon: Icons.trending_up_rounded,
          ),
          _StatCard(
            label: lang == 'fa' ? 'کل P&L' : 'Total P&L',
            value: totalPnl.toStringAsFixed(0),
            color: pnlColor,
            icon: totalPnl >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          ),
          _StatCard(
            label: lang == 'fa' ? 'Win Rate' : 'Win Rate',
            value: '${provider.winRate.toStringAsFixed(0)}%',
            color: AppTheme.orange,
            icon: Icons.emoji_events_rounded,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label, required this.value,
    required this.color, required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 18.sp),
        SizedBox(height: 4.h),
        Text(value, style: TextStyle(
            color: color, fontSize: 14.sp, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(
            color: AppTheme.textSec(context), fontSize: 10.sp)),
      ]),
    );
  }
}

// ── لیست معاملات ─────────────────────────────────────────────────────────────

class _TradeList extends StatelessWidget {
  final List<TradeModel> trades;
  final String lang;
  final bool isOpen;

  const _TradeList({required this.trades, required this.lang, required this.isOpen});

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bar_chart_rounded, size: 48.sp, color: AppTheme.textSec(context)),
          SizedBox(height: 10.h),
          Text(
            lang == 'fa'
                ? (isOpen ? 'معامله باز ندارید' : 'معامله بسته‌ای ندارید')
                : (isOpen ? 'No open trades' : 'No closed trades'),
            style: TextStyle(color: AppTheme.textSec(context), fontSize: 13.sp),
          ),
        ]),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(12.w),
      itemCount: trades.length,
      itemBuilder: (_, i) => _TradeCard(
        trade: trades[i],
        lang:  lang,
      ).animate().fadeIn(duration: 250.ms, delay: Duration(milliseconds: i * 50)),
    );
  }
}

// ── کارت معامله ──────────────────────────────────────────────────────────────

class _TradeCard extends StatelessWidget {
  final TradeModel trade;
  final String lang;

  const _TradeCard({required this.trade, required this.lang});

  @override
  Widget build(BuildContext context) {
    final isBuy  = trade.isBuy;
    final color  = isBuy ? AppTheme.green : AppTheme.red;
    final pnl    = trade.pnl;
    final pnlCol = pnl == null ? AppTheme.textSec(context)
        : (pnl >= 0 ? AppTheme.green : AppTheme.red);

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── ردیف اصلی ───────────────────────────────────────────
          Padding(
            padding: EdgeInsets.all(12.w),
            child: Row(children: [
              // آیکون
              Container(
                width: 42.w, height: 42.w,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Icon(
                  isBuy ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: color, size: 18.sp,
                ),
              ),
              SizedBox(width: 10.w),

              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(trade.symbol,
                        style: TextStyle(color: AppTheme.text(context),
                            fontSize: 14.sp, fontWeight: FontWeight.bold)),
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        isBuy ? (lang == 'fa' ? 'خرید' : 'BUY')
                               : (lang == 'fa' ? 'فروش' : 'SELL'),
                        style: TextStyle(color: color,
                            fontSize: 9.sp, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (trade.isOpen) ...[
                      SizedBox(width: 4.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: AppTheme.blue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          lang == 'fa' ? '🔴 باز' : '🔴 OPEN',
                          style: TextStyle(color: AppTheme.blue,
                              fontSize: 9.sp, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ]),
                  SizedBox(height: 4.h),
                  Text(
                    lang == 'fa'
                        ? 'ورود: ${trade.entry}  •  حجم: ${trade.lotSize}'
                        : 'Entry: ${trade.entry}  •  Lot: ${trade.lotSize}',
                    style: TextStyle(color: AppTheme.textSec(context), fontSize: 11.sp),
                  ),
                  if (trade.hasSL || trade.hasTP) ...[
                    SizedBox(height: 2.h),
                    Row(children: [
                      if (trade.hasSL) _SmallChip(
                        'SL: ${trade.stopLoss}', AppTheme.red),
                      if (trade.hasSL && trade.hasTP) SizedBox(width: 6.w),
                      if (trade.hasTP) _SmallChip(
                        'TP: ${trade.takeProfit}', AppTheme.green),
                      if (trade.riskRewardRatio != null) ...[
                        SizedBox(width: 6.w),
                        _SmallChip('R:R ${trade.riskRewardRatio!.toStringAsFixed(1)}',
                            AppTheme.orange),
                      ],
                    ]),
                  ],
                ],
              )),

              // P&L یا دکمه بستن
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (pnl != null)
                  Text(
                    '${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(1)}',
                    style: TextStyle(color: pnlCol,
                        fontSize: 14.sp, fontWeight: FontWeight.bold),
                  )
                else
                  GestureDetector(
                    onTap: () => _closeTradeDialog(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppTheme.primary, Color(0xFF9C27B0)]),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Text(
                        lang == 'fa' ? 'بستن' : 'Close',
                        style: TextStyle(color: Colors.white,
                            fontSize: 11.sp, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                SizedBox(height: 2.h),
                Text(
                  _formatDate(trade.openedAt, lang),
                  style: TextStyle(color: AppTheme.textSec(context), fontSize: 9.sp),
                ),
              ]),
            ]),
          ),

          // ── عکس چارت ─────────────────────────────────────────────
          if (trade.hasImage) ...[
            Divider(color: AppTheme.divider(context), height: 1),
            ClipRRect(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16.r),
                bottomRight: Radius.circular(16.r),
              ),
              child: CachedNetworkImage(
                imageUrl: trade.imageUrl!,
                height: 160.h,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 160.h,
                  color: AppTheme.surface(context),
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 160.h,
                  color: AppTheme.surface(context),
                  child: Icon(Icons.broken_image_outlined,
                      color: AppTheme.textSec(context)),
                ),
              ),
            ),
          ],

          // ── توضیحات ───────────────────────────────────────────────
          if (trade.notes != null && trade.notes!.isNotEmpty) ...[
            Divider(color: AppTheme.divider(context), height: 1),
            Padding(
              padding: EdgeInsets.all(10.w),
              child: Text(trade.notes!,
                  style: TextStyle(
                      color: AppTheme.textSec(context), fontSize: 11.sp)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _closeTradeDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.card(context),
        title: Text(lang == 'fa' ? 'بستن معامله' : 'Close Trade',
            style: TextStyle(color: AppTheme.text(context), fontSize: 14.sp)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr,
          style: TextStyle(color: AppTheme.text(context)),
          decoration: InputDecoration(
            labelText: lang == 'fa' ? 'قیمت خروج' : 'Exit Price',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang == 'fa' ? 'انصراف' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text);
              if (val != null) {
                context.read<TradeProvider>().closeTrade(trade.id, val);
                Navigator.pop(context);
              }
            },
            child: Text(lang == 'fa' ? 'ثبت' : 'Save'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt, String lang) {
    return '${dt.year}/${dt.month.toString().padLeft(2,'0')}/${dt.day.toString().padLeft(2,'0')}';
  }
}

class _SmallChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 9.sp)),
    );
  }
}

// ── Add Trade Bottom Sheet ────────────────────────────────────────────────────

class _AddTradeSheet extends StatefulWidget {
  final String lang;
  const _AddTradeSheet({required this.lang});

  @override
  State<_AddTradeSheet> createState() => _AddTradeSheetState();
}

class _AddTradeSheetState extends State<_AddTradeSheet> {
  final _symbolCtrl = TextEditingController();
  final _entryCtrl  = TextEditingController();
  final _lotCtrl    = TextEditingController(text: '0.01');
  final _slCtrl     = TextEditingController();
  final _tpCtrl     = TextEditingController();
  final _notesCtrl  = TextEditingController();
  String _type      = 'buy';
  File?  _imageFile;
  bool   _uploading = false;

  @override
  void dispose() {
    _symbolCtrl.dispose(); _entryCtrl.dispose(); _lotCtrl.dispose();
    _slCtrl.dispose(); _tpCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (result != null) setState(() => _imageFile = File(result.path));
  }

  Future<void> _submit() async {
    if (_symbolCtrl.text.isEmpty || _entryCtrl.text.isEmpty) return;

    setState(() => _uploading = true);

    await context.read<TradeProvider>().addTrade(
      symbol:     _symbolCtrl.text,
      type:       _type,
      entry:      double.tryParse(_entryCtrl.text) ?? 0,
      lotSize:    double.tryParse(_lotCtrl.text)   ?? 0.01,
      stopLoss:   double.tryParse(_slCtrl.text),
      takeProfit: double.tryParse(_tpCtrl.text),
      notes:      _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
      imageFile:  _imageFile,
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final lang  = widget.lang;
    final isRtl = lang == 'fa';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w,
            MediaQuery.of(context).viewInsets.bottom + 24.h),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // handle
              Center(child: Container(
                width: 40.w, height: 4.h,
                decoration: BoxDecoration(
                  color: AppTheme.border(context),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              )),
              SizedBox(height: 14.h),

              Row(children: [
                Icon(Icons.add_chart_rounded, color: AppTheme.green, size: 20.sp),
                SizedBox(width: 8.w),
                Text(lang == 'fa' ? 'ورود به معامله' : 'Enter Position',
                    style: TextStyle(color: AppTheme.text(context),
                        fontSize: 15.sp, fontWeight: FontWeight.bold)),
              ]),
              SizedBox(height: 16.h),

              // BUY / SELL toggle
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.card(context),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() => _type = 'buy'),
                    child: AnimatedContainer(
                      duration: 200.ms,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: BoxDecoration(
                        color: _type == 'buy'
                            ? AppTheme.green.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Center(child: Text(
                        lang == 'fa' ? '📈 خرید' : '📈 BUY',
                        style: TextStyle(
                          color: _type == 'buy' ? AppTheme.green : AppTheme.textSec(context),
                          fontSize: 13.sp, fontWeight: FontWeight.bold,
                        ),
                      )),
                    ),
                  )),
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() => _type = 'sell'),
                    child: AnimatedContainer(
                      duration: 200.ms,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: BoxDecoration(
                        color: _type == 'sell'
                            ? AppTheme.red.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Center(child: Text(
                        lang == 'fa' ? '📉 فروش' : '📉 SELL',
                        style: TextStyle(
                          color: _type == 'sell' ? AppTheme.red : AppTheme.textSec(context),
                          fontSize: 13.sp, fontWeight: FontWeight.bold,
                        ),
                      )),
                    ),
                  )),
                ]),
              ),
              SizedBox(height: 14.h),

              // Symbol + Entry
              Row(children: [
                Expanded(child: _Field(ctrl: _symbolCtrl,
                    label: lang == 'fa' ? 'نماد' : 'Symbol',
                    hint: 'XAUUSD', caps: true)),
                SizedBox(width: 10.w),
                Expanded(child: _Field(ctrl: _entryCtrl,
                    label: lang == 'fa' ? 'قیمت ورود' : 'Entry', numeric: true)),
              ]),
              SizedBox(height: 10.h),

              // Lot + SL + TP
              Row(children: [
                Expanded(child: _Field(ctrl: _lotCtrl,
                    label: lang == 'fa' ? 'حجم (Lot)' : 'Lot Size', numeric: true)),
                SizedBox(width: 10.w),
                Expanded(child: _Field(ctrl: _slCtrl,
                    label: 'Stop Loss', numeric: true, optional: true)),
                SizedBox(width: 10.w),
                Expanded(child: _Field(ctrl: _tpCtrl,
                    label: 'Take Profit', numeric: true, optional: true)),
              ]),
              SizedBox(height: 10.h),

              // Notes
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                style: TextStyle(color: AppTheme.text(context), fontSize: 13.sp),
                decoration: InputDecoration(
                  labelText: lang == 'fa' ? 'توضیحات (اختیاری)' : 'Notes (optional)',
                  prefixIcon: Icon(Icons.notes_rounded,
                      color: AppTheme.primary, size: 18.sp),
                ),
              ),
              SizedBox(height: 12.h),

              // عکس چارت
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 60.h,
                    decoration: BoxDecoration(
                      color: _imageFile != null
                          ? AppTheme.green.withOpacity(0.1)
                          : AppTheme.card(context),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: _imageFile != null
                            ? AppTheme.green : AppTheme.border(context),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: _imageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(11.r),
                            child: Image.file(_imageFile!, fit: BoxFit.cover))
                        : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                color: AppTheme.textSec(context), size: 22.sp),
                            Text(
                              lang == 'fa' ? 'عکس چارت' : 'Chart Image',
                              style: TextStyle(color: AppTheme.textSec(context),
                                  fontSize: 11.sp),
                            ),
                          ]),
                  ),
                )),
                if (_imageFile != null) ...[
                  SizedBox(width: 8.w),
                  GestureDetector(
                    onTap: () => setState(() => _imageFile = null),
                    child: Container(
                      width: 36.w, height: 36.w,
                      decoration: BoxDecoration(
                        color: AppTheme.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(Icons.close_rounded, color: AppTheme.red, size: 18.sp),
                    ),
                  ),
                ],
              ]),

              if (!GoogleDriveService.instance.isSignedIn && _imageFile != null)
                Padding(
                  padding: EdgeInsets.only(top: 6.h),
                  child: Text(
                    lang == 'fa'
                        ? '⚠️ برای ذخیره عکس در Google Drive وارد شوید'
                        : '⚠️ Sign in to Google Drive to save the image',
                    style: TextStyle(color: AppTheme.orange, fontSize: 10.sp),
                  ),
                ),

              SizedBox(height: 18.h),

              // دکمه ثبت
              ElevatedButton(
                onPressed: _uploading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.green,
                  minimumSize: Size(double.infinity, 50.h),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r)),
                ),
                child: _uploading
                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SizedBox(width: 18.w, height: 18.w,
                            child: const CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2)),
                        SizedBox(width: 10.w),
                        Text(lang == 'fa' ? 'در حال آپلود...' : 'Uploading...',
                            style: TextStyle(fontSize: 13.sp)),
                      ])
                    : Text(
                        lang == 'fa' ? 'ثبت معامله' : 'Save Trade',
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String? hint;
  final bool numeric;
  final bool optional;
  final bool caps;

  const _Field({
    required this.ctrl,
    required this.label,
    this.hint,
    this.numeric = false,
    this.optional = false,
    this.caps = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      textDirection: TextDirection.ltr,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      textCapitalization: caps ? TextCapitalization.characters : TextCapitalization.none,
      style: TextStyle(color: AppTheme.text(context), fontSize: 13.sp),
      decoration: InputDecoration(
        labelText: label + (optional ? ' *' : ''),
        hintText: hint,
        contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      ),
    );
  }
}
