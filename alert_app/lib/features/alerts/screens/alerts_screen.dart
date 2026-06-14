import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/alert_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/shimmer_widgets.dart';
import '../../../core/models/alert_model.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId != null) {
      await context.read<AlertProvider>().loadAlerts(auth.userId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lang   = context.watch<LocaleProvider>().lang;
    final isDark = context.watch<ThemeProvider>().isDark;
    final auth   = context.watch<AuthProvider>();
    final prov   = context.watch<AlertProvider>();
    final active = prov.alerts.where((a) => !a.triggered).toList();
    final isRtl  = lang == 'fa';

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
        body: RefreshIndicator(
          onRefresh: _load,
          color: AppTheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [

              // ── Gradient Header ───────────────────────────────────────
              SliverAppBar(
                expandedHeight: 140.h,
                floating:       false,
                pinned:         true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: _GradientHeader(
                    lang: lang, isDark: isDark,
                    activeCount: active.length,
                    isLoading: prov.loading,
                  ),
                ),
                actions: [
                  // History
                  IconButton(
                    icon: Icon(Icons.history_rounded,
                        color: Colors.white70, size: 20.sp),
                    onPressed: () => context.push('/alerts/history'),
                  ),
                  SizedBox(width: 4.w),
                ],
              ),

              // ── Content ───────────────────────────────────────────────
              if (prov.loading)
                SliverPadding(
                  padding: EdgeInsets.only(top: 12.h, bottom: 120.h),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => const ShimmerAlertTile(),
                      childCount: 5,
                    ),
                  ),
                )
              else if (active.isEmpty)
                SliverFillRemaining(
                  child: _EmptyState(lang: lang, isDark: isDark,
                      onAdd: () => _showAddSheet(context, lang, isDark)),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 120.h),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _AlertGlassCard(
                        key:    ValueKey(active[i].id),
                        alert:  active[i],
                        lang:   lang,
                        isDark: isDark,
                        index:  i,
                        onDelete: () async {
                          final auth = context.read<AuthProvider>();
                          if (auth.userId != null) {
                            await context.read<AlertProvider>()
                                .deleteAlert(active[i].id, auth.userId!);
                          }
                        },
                      ),
                      childCount: active.length,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── FAB ────────────────────────────────────────────────────────
        floatingActionButton: _PlusFab(
          lang:   lang,
          isDark: isDark,
          onTap:  () => _showAddSheet(context, lang, isDark),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  void _showAddSheet(BuildContext ctx, String lang, bool isDark) {
    showModalBottomSheet(
      context:         ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddAlertSheet(lang: lang, isDark: isDark),
    );
  }
}

// ── Gradient Header ───────────────────────────────────────────────────────────

class _GradientHeader extends StatelessWidget {
  const _GradientHeader({
    required this.lang,
    required this.isDark,
    required this.activeCount,
    required this.isLoading,
  });

  final String lang;
  final bool   isDark;
  final int    activeCount;
  final bool   isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A42CC), Color(0xFF6C63FF), Color(0xFF00B4D8)],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:  MainAxisAlignment.end,
            children: [
              Text(
                lang == 'fa' ? 'آلرت‌های قیمت' : 'Price Alerts',
                style: TextStyle(
                  fontSize: 24.sp, fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4.h),
              Row(children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    isLoading
                        ? (lang == 'fa' ? 'در حال بارگذاری...' : 'Loading...')
                        : '$activeCount ${lang == 'fa' ? 'آلرت فعال' : 'active'}',
                    style: TextStyle(
                      fontSize: 12.sp, color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Glass Alert Card ──────────────────────────────────────────────────────────

class _AlertGlassCard extends StatelessWidget {
  const _AlertGlassCard({
    super.key,
    required this.alert,
    required this.lang,
    required this.isDark,
    required this.index,
    required this.onDelete,
  });

  final AlertModel    alert;
  final String        lang;
  final bool          isDark;
  final int           index;
  final VoidCallback  onDelete;

  bool   get _isUp   => alert.isAbove;
  Color  get _color  => _isUp ? AppTheme.green : AppTheme.red;
  double get _target => alert.targetPrice;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key:       ValueKey('dismiss_${alert.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        decoration: BoxDecoration(
          color:        AppTheme.red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20.r),
        ),
        alignment: Alignment.centerRight,
        padding:   EdgeInsets.only(right: 24.w),
        child: Icon(Icons.delete_outline_rounded,
            color: AppTheme.red, size: 24.sp),
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
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: _color.withOpacity(0.25),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _color.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // ── Top row ──────────────────────────────────────────
                  Row(
                    children: [
                      // Direction badge
                      Container(
                        width:  44.w, height: 44.w,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _color.withOpacity(0.2),
                              _color.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end:   Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _color.withOpacity(0.3), width: 1),
                        ),
                        child: Icon(
                          _isUp
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          color: _color, size: 20.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      // Symbol + direction label
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alert.symbol,
                              style: TextStyle(
                                fontSize: 18.sp, fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                                fontFamily: 'TexGyreAdventor',
                              ),
                            ),
                            Text(
                              lang == 'fa'
                                  ? (_isUp ? '⬆️ انتظار افزایش' : '⬇️ انتظار کاهش')
                                  : (_isUp ? '⬆️ Waiting to rise' : '⬇️ Waiting to fall'),
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: _color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Target price
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            lang == 'fa' ? 'هدف' : 'Target',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                          Text(
                            _formatPrice(_target),
                            style: TextStyle(
                              fontSize: 16.sp, fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                              fontFamily: 'TexGyreAdventor',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),

                  // ── Progress bar ─────────────────────────────────────
                  _ProgressBar(color: _color, isDark: isDark),
                  SizedBox(height: 8.h),

                  // ── Bottom row ───────────────────────────────────────
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 12.sp,
                          color: isDark ? Colors.white30 : Colors.black26),
                      SizedBox(width: 4.w),
                      Text(
                        alert.createdAt.substring(0, 10),
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: isDark ? Colors.white30 : Colors.black26,
                          fontFamily: 'TexGyreAdventor',
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          '#${alert.id}',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'TexGyreAdventor',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      )
          .animate()
          .fadeIn(delay: (index * 60).ms, duration: 300.ms)
          .slideX(begin: 0.05, end: 0),
    );
  }

  static String _formatPrice(double p) {
    if (p >= 1000) return p.toStringAsFixed(2)
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    if (p >= 1)    return p.toStringAsFixed(5).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return p.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
}

// ── Animated progress bar ─────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.color, required this.isDark});
  final Color color;
  final bool  isDark;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, box) => Container(
        height: 4.h,
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
          borderRadius: BorderRadius.circular(2.r),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width:  box.maxWidth * 0.6,
            height: 4.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.6), color],
              ),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
        ).animate().scaleX(
            begin: 0, end: 1,
            alignment: Alignment.centerLeft,
            duration: 600.ms, curve: Curves.easeOut),
      ),
    );
  }
}

// ── Add Alert Bottom Sheet ────────────────────────────────────────────────────

class _AddAlertSheet extends StatefulWidget {
  const _AddAlertSheet({required this.lang, required this.isDark});
  final String lang;
  final bool   isDark;

  @override
  State<_AddAlertSheet> createState() => _AddAlertSheetState();
}

class _AddAlertSheetState extends State<_AddAlertSheet> {
  final _symbolCtrl = TextEditingController();
  final _priceCtrl  = TextEditingController();
  bool  _loading    = false;
  String? _error;
  String? _currentPrice;

  static const _quickSymbols = [
    ('🥇', 'XAUUSD'), ('💶', 'EURUSD'), ('🔷', 'BTC'),
    ('💵', 'GBP'),    ('🫙', 'OIL'),    ('📈', 'US500'),
  ];

  @override
  void dispose() {
    _symbolCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchPrice() async {
    final sym = _symbolCtrl.text.trim().toUpperCase();
    if (sym.isEmpty) return;
    setState(() => _loading = true);
    try {
      final data  = await context.read<AlertProvider>().getPrice(sym);
      final price = data?['price'];
      if (price != null && mounted) {
        setState(() {
          _currentPrice = price.toString();
          _loading      = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final sym   = _symbolCtrl.text.trim().toUpperCase();
    final price = double.tryParse(_priceCtrl.text.trim());
    if (sym.isEmpty || price == null) {
      setState(() => _error = widget.lang == 'fa'
          ? 'نماد و قیمت رو وارد کن'
          : 'Enter symbol and price');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final auth = context.read<AuthProvider>();
      if (auth.userId == null) return;
      await context.read<AlertProvider>().addAlert(
        userId:      auth.userId!,
        symbol:      sym,
        targetPrice: price,
        username:    auth.username,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() {
        _error   = e.toString();
        _loading = false;
      });
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
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.15),
            blurRadius: 30, offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36.w, height: 4.h,
              decoration: BoxDecoration(
                color:        isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // Title
          Text(
            lang == 'fa' ? '🔔 آلرت جدید' : '🔔 New Alert',
            style: TextStyle(
              fontSize: 18.sp, fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(height: 16.h),

          // Quick symbol chips
          SizedBox(
            height: 34.h,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _quickSymbols.map((s) => GestureDetector(
                onTap: () {
                  _symbolCtrl.text = s.$2;
                  _fetchPrice();
                },
                child: Container(
                  margin: EdgeInsets.only(right: 8.w),
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                        color: AppTheme.primary.withOpacity(0.2)),
                  ),
                  child: Text('${s.$1} ${s.$2}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              )).toList(),
            ),
          ),
          SizedBox(height: 14.h),

          // Symbol field
          _GlassTextField(
            controller: _symbolCtrl,
            hint:       lang == 'fa' ? 'نماد — مثال: XAUUSD' : 'Symbol — e.g. XAUUSD',
            icon:       Icons.candlestick_chart_outlined,
            isDark:     isDark,
            caps:       true,
            onSubmit:   (_) => _fetchPrice(),
          ),
          if (_currentPrice != null) ...[
            SizedBox(height: 6.h),
            Padding(
              padding: EdgeInsets.only(right: 4.w),
              child: Text(
                '${lang == 'fa' ? 'قیمت فعلی' : 'Current price'}: $_currentPrice',
                style: TextStyle(
                  fontSize: 11.sp, color: AppTheme.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          SizedBox(height: 10.h),

          // Price field
          _GlassTextField(
            controller: _priceCtrl,
            hint:       lang == 'fa' ? 'قیمت هدف' : 'Target price',
            icon:       Icons.flag_outlined,
            isDark:     isDark,
            numeric:    true,
          ),
          SizedBox(height: 10.h),

          if (_error != null) ...[
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color:        AppTheme.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(_error!,
                  style: TextStyle(fontSize: 11.sp, color: AppTheme.red)),
            ),
            SizedBox(height: 10.h),
          ],

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 52.h,
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
                  gradient: _loading
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFF4A42CC), Color(0xFF6C63FF)],
                          begin: Alignment.centerLeft,
                          end:   Alignment.centerRight,
                        ),
                  color:  _loading
                      ? (isDark ? Colors.white12 : Colors.black12)
                      : null,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Container(
                  alignment: Alignment.center,
                  child: _loading
                      ? SizedBox(
                          width: 20.w, height: 20.w,
                          child: const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          lang == 'fa' ? 'ثبت آلرت' : 'Set Alert',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Glass text field ──────────────────────────────────────────────────────────

class _GlassTextField extends StatelessWidget {
  const _GlassTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.isDark,
    this.caps    = false,
    this.numeric = false,
    this.onSubmit,
  });

  final TextEditingController  controller;
  final String                 hint;
  final IconData               icon;
  final bool                   isDark;
  final bool                   caps;
  final bool                   numeric;
  final ValueChanged<String>?  onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller:           controller,
      textCapitalization:   caps ? TextCapitalization.characters : TextCapitalization.none,
      keyboardType:         numeric ? TextInputType.number : TextInputType.text,
      textDirection:        TextDirection.ltr,
      onSubmitted:          onSubmit,
      style: TextStyle(
        fontSize: 14.sp, fontFamily: 'TexGyreAdventor',
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: TextStyle(
            color: isDark ? Colors.white30 : Colors.black26, fontSize: 13.sp),
        prefixIcon: Icon(icon,
            color: AppTheme.primary, size: 18.sp),
        filled:    true,
        fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
        border:    OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide:   BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide:   BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 12.w),
      ),
    );
  }
}

// ── FAB ───────────────────────────────────────────────────────────────────────

class _PlusFab extends StatelessWidget {
  const _PlusFab({required this.lang, required this.isDark, required this.onTap});
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
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.4),
                blurRadius: 16, offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 20.sp),
              SizedBox(width: 6.w),
              Text(
                lang == 'fa' ? 'آلرت جدید' : 'New Alert',
                style: TextStyle(
                  fontSize: 14.sp, fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        )
            .animate()
            .scale(duration: 200.ms, curve: Curves.elasticOut),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.lang, required this.isDark, required this.onAdd});
  final String lang;
  final bool   isDark;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100.w, height: 100.w,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primary.withOpacity(0.15),
                AppTheme.accent.withOpacity(0.1),
              ],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.notifications_none_rounded,
              size: 48.sp,
              color: AppTheme.primary.withOpacity(0.6)),
        )
            .animate().scale(duration: 500.ms, curve: Curves.elasticOut),
        SizedBox(height: 20.h),
        Text(
          lang == 'fa' ? 'هنوز آلرتی نداری' : 'No alerts yet',
          style: TextStyle(
            fontSize: 18.sp, fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          lang == 'fa'
              ? 'وقتی قیمت به هدفت برسه، فوری خبر میگیری'
              : "You'll be notified the moment price hits your target",
          style: TextStyle(
            fontSize: 13.sp,
            color: isDark ? Colors.white30 : Colors.black38,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 24.h),
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
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 12, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              lang == 'fa' ? 'اولین آلرتم رو بزار' : 'Set my first alert',
              style: TextStyle(
                fontSize: 14.sp, fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ).animate().fadeIn(delay: 200.ms),
      ],
    );
  }
}
