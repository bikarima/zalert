import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/widgets/shimmer_widgets.dart';
import '../../../core/widgets/price_change_indicator.dart';
import '../providers/watchlist_provider.dart';
import '../models/watchlist_item.dart';

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang  = context.watch<LocaleProvider>().lang;
    final isRtl = lang == 'fa';
    final isDark = context.watch<ThemeProvider>().isDark;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
          elevation: 0,
          title: Text(
            lang == 'fa' ? 'واچ‌لیست' : 'Watchlist',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          actions: [
            // Reset button
            IconButton(
              icon: Icon(Icons.restore_rounded,
                  color: isDark ? Colors.white54 : Colors.black38, size: 20.sp),
              tooltip: lang == 'fa' ? 'بازنشانی' : 'Reset',
              onPressed: () => _confirmReset(context, lang),
            ),
            // Add symbol button
            IconButton(
              icon: Icon(Icons.add_rounded,
                  color: AppTheme.primary, size: 22.sp),
              tooltip: lang == 'fa' ? 'افزودن نماد' : 'Add symbol',
              onPressed: () => _showAddSheet(context, lang, isDark),
            ),
            SizedBox(width: 4.w),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => context.read<WatchlistProvider>().refreshPrices(),
          color: AppTheme.primary,
          child: Consumer<WatchlistProvider>(
            builder: (_, provider, __) {
              if (provider.loading) {
                return const ShimmerList(count: 6);
              }
              // Capture snapshot once — prevents race between itemCount and itemBuilder
              final items = provider.items;
              if (items.isEmpty) {
                return _EmptyWatchlist(lang: lang, isDark: isDark,
                    onAdd: () => _showAddSheet(context, lang, isDark));
              }
              return ListView.builder(
                padding: EdgeInsets.fromLTRB(0, 8.h, 0, 100.h),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  if (i >= items.length) return const SizedBox.shrink();
                  final item = items[i];
                  return _WatchlistTile(
                    key: ValueKey(item.symbol),
                    item: item,
                    isDark: isDark,
                    lang: lang,
                    onRemove: () => provider.removeSymbol(item.symbol),
                  ).animate().fadeIn(delay: (i * 40).ms);
                },
              );
              },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, String lang, bool isDark) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            20.w, 20.h, 20.w, MediaQuery.of(context).viewInsets.bottom + 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang == 'fa' ? 'افزودن نماد' : 'Add Symbol',
              style: TextStyle(
                fontSize: 16.sp, fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(
                fontSize: 14.sp, fontFamily: 'TexGyreAdventor',
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: lang == 'fa' ? 'مثال: XAUUSD' : 'e.g. XAUUSD',
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                filled: true,
                fillColor: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.search, color: AppTheme.primary),
              ),
            ),
            SizedBox(height: 12.h),
            // Quick symbols
            Wrap(
              spacing: 8.w, runSpacing: 8.h,
              children: WatchlistItem.defaults.map((d) => GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  context.read<WatchlistProvider>().addSymbol(
                      d.symbol, emoji: d.emoji, label: d.label);
                },
                child: Chip(
                  label: Text('${d.emoji} ${d.symbol}',
                      style: TextStyle(fontSize: 11.sp)),
                  backgroundColor: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.05),
                ),
              )).toList(),
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final sym = ctrl.text.trim().toUpperCase();
                  if (sym.isNotEmpty) {
                    context.read<WatchlistProvider>().addSymbol(sym);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r)),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                ),
                child: Text(
                  lang == 'fa' ? 'افزودن' : 'Add',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context, String lang) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(lang == 'fa' ? 'بازنشانی واچ‌لیست' : 'Reset Watchlist'),
        content: Text(lang == 'fa'
            ? 'واچ‌لیست به نمادهای پیش‌فرض بازنشانی میشه.'
            : 'Watchlist will be reset to default symbols.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(lang == 'fa' ? 'انصراف' : 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<WatchlistProvider>().resetToDefaults();
              Navigator.pop(context);
            },
            child: Text(
              lang == 'fa' ? 'بازنشانی' : 'Reset',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _WatchlistTile extends StatelessWidget {
  const _WatchlistTile({
    super.key,
    required this.item,
    required this.isDark,
    required this.lang,
    required this.onRemove,
  });

  final WatchlistItem item;
  final bool isDark;
  final String lang;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('dismiss_${item.symbol}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20.w),
        color: const Color(0xFFFF1744).withOpacity(0.15),
        child: Icon(Icons.delete_outline, color: const Color(0xFFFF1744), size: 22.sp),
      ),
      onDismissed: (_) => onRemove(),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h),
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 6, offset: const Offset(0, 2),
          )],
        ),
        child: Row(
          children: [
            // Emoji
            Text(item.emoji, style: TextStyle(fontSize: 22.sp)),
            SizedBox(width: 12.w),
            // Symbol + label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.symbol,
                    style: TextStyle(
                      fontSize: 15.sp, fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                      fontFamily: 'TexGyreAdventor',
                    ),
                  ),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
            // Price
            if (item.price != null)
              PriceChangeIndicator(
                price: item.price!,
                previousPrice: item.prevPrice,
                fontSize: 15.sp,
                showArrow: true,
                showChange: true,
              )
            else
              ShimmerBox(width: 80.w, height: 18.h),
            SizedBox(width: 8.w),
            // Drag handle
            Icon(Icons.drag_handle_rounded,
                color: isDark ? Colors.white24 : Colors.black12, size: 18.sp),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyWatchlist extends StatelessWidget {
  const _EmptyWatchlist({required this.lang, required this.isDark, required this.onAdd});
  final String lang;
  final bool isDark;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('📊', style: TextStyle(fontSize: 48.sp))
              .animate().scale(duration: 400.ms),
          SizedBox(height: 16.h),
          Text(
            lang == 'fa' ? 'واچ‌لیستت خالیه!' : 'Your watchlist is empty!',
            style: TextStyle(
              fontSize: 16.sp, fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            lang == 'fa' ? 'نمادهای موردنظرت رو اضافه کن' : 'Add symbols to track live prices',
            style: TextStyle(fontSize: 13.sp,
                color: isDark ? Colors.white38 : Colors.black38),
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(lang == 'fa' ? 'افزودن نماد' : 'Add Symbol'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r)),
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            ),
          ),
        ],
      ),
    );
  }
}
