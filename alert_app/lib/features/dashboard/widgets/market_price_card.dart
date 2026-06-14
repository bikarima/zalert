import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/price_change_indicator.dart';

/// Live market price card with sparkline chart.
/// Shows symbol, emoji label, current price, change%, and mini line chart.
class MarketPriceCard extends StatelessWidget {
  const MarketPriceCard({
    super.key,
    required this.emoji,
    required this.symbol,
    required this.label,
    required this.price,
    required this.prevPrice,
    required this.lang,
    required this.onTap,
  });

  final String  emoji;
  final String  symbol;
  final String  label;
  final double? price;
  final double? prevPrice;
  final String  lang;
  final VoidCallback onTap;

  bool get _isUp =>
      price == null || prevPrice == null || price! >= prevPrice!;

  Color get _color => _isUp ? const Color(0xFF00C853) : const Color(0xFFFF1744);

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150.w,
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: _color.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ── Symbol row ────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(emoji, style: TextStyle(fontSize: 16.sp)),
                if (price != null && prevPrice != null)
                  _ChangeChip(price: price!, prev: prevPrice!),
              ],
            ),
            // ── Price ─────────────────────────────────────────────
            if (price != null)
              PriceChangeIndicator(
                price: price!,
                previousPrice: prevPrice,
                fontSize: 14.sp,
                showArrow: false,
              )
            else
              Text('—', style: TextStyle(fontSize: 14.sp,
                  color: isDark ? Colors.white38 : Colors.black26)),
            // ── Label ─────────────────────────────────────────────
            Text(
              symbol,
              style: TextStyle(
                fontSize: 10.sp,
                color: isDark ? Colors.white54 : Colors.black45,
                fontFamily: 'TexGyreAdventor',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangeChip extends StatelessWidget {
  const _ChangeChip({required this.price, required this.prev});
  final double price, prev;

  @override
  Widget build(BuildContext context) {
    if (prev <= 0) return const SizedBox.shrink();
    final pct  = (price - prev) / prev * 100;
    final up   = pct >= 0;
    final text = '${up ? '+' : ''}${pct.toStringAsFixed(2)}%';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: (up ? const Color(0xFF00C853) : const Color(0xFFFF1744)).withOpacity(0.15),
        borderRadius: BorderRadius.circular(5.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9.sp,
          fontWeight: FontWeight.w700,
          color: up ? const Color(0xFF00C853) : const Color(0xFFFF1744),
          fontFamily: 'TexGyreAdventor',
        ),
      ),
    );
  }
}
