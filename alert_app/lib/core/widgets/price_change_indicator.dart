import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Animated widget that shows a price with directional color and arrow.
/// Flashes green/red briefly when price changes.
class PriceChangeIndicator extends StatefulWidget {
  const PriceChangeIndicator({
    super.key,
    required this.price,
    required this.previousPrice,
    this.fontSize,
    this.showArrow = true,
    this.showChange = false,
  });

  final double price;
  final double? previousPrice;
  final double? fontSize;
  final bool showArrow;
  final bool showChange;

  @override
  State<PriceChangeIndicator> createState() => _PriceChangeIndicatorState();
}

class _PriceChangeIndicatorState extends State<PriceChangeIndicator> {
  bool _flashing = false;

  @override
  void didUpdateWidget(PriceChangeIndicator old) {
    super.didUpdateWidget(old);
    if (old.price != widget.price && widget.previousPrice != null) {
      _flash();
    }
  }

  void _flash() {
    if (!mounted) return;
    setState(() => _flashing = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _flashing = false);
    });
  }

  bool get _isUp =>
      widget.previousPrice == null || widget.price >= widget.previousPrice!;

  Color _color(BuildContext ctx) {
    if (!_flashing) return Theme.of(ctx).colorScheme.onSurface;
    return _isUp ? const Color(0xFF00C853) : const Color(0xFFFF1744);
  }

  @override
  Widget build(BuildContext context) {
    final price    = _formatPrice(widget.price);
    final fontSize = widget.fontSize ?? 16.sp;
    final color    = _color(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showArrow && widget.previousPrice != null)
          Icon(
            _isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
            color: _isUp ? const Color(0xFF00C853) : const Color(0xFFFF1744),
            size: fontSize + 8,
          ),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: color,
            fontFamily: 'TexGyreAdventor',
          ),
          child: Text(price),
        ).animate(key: ValueKey(widget.price)).shimmer(
          duration: 400.ms,
          color: _isUp ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
        ),
        if (widget.showChange && widget.previousPrice != null && widget.previousPrice! > 0) ...[
          SizedBox(width: 4.w),
          _ChangeChip(price: widget.price, prev: widget.previousPrice!),
        ],
      ],
    );
  }

  static String _formatPrice(double p) {
    if (p >= 1000) return p.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    if (p >= 1)    return p.toStringAsFixed(5).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return p.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
}

class _ChangeChip extends StatelessWidget {
  const _ChangeChip({required this.price, required this.prev});
  final double price, prev;

  @override
  Widget build(BuildContext context) {
    final pct  = ((price - prev) / prev * 100);
    final up   = pct >= 0;
    final text = '${up ? '+' : ''}${pct.toStringAsFixed(2)}%';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: (up ? const Color(0xFF00C853) : const Color(0xFFFF1744)).withOpacity(0.15),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w600,
          color: up ? const Color(0xFF00C853) : const Color(0xFFFF1744),
          fontFamily: 'TexGyreAdventor',
        ),
      ),
    );
  }
}
