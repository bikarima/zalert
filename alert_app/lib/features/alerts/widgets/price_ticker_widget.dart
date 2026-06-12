import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

class PriceTickerWidget extends StatefulWidget {
  final String lang;
  const PriceTickerWidget({super.key, required this.lang});

  @override
  State<PriceTickerWidget> createState() => _PriceTickerWidgetState();
}

class _PriceTickerWidgetState extends State<PriceTickerWidget> {
  final _symbols = ['XAUUSD', 'EURUSD', 'WTI', 'GBPUSD'];
  final Map<String, double?> _prices = {};
  final Map<String, double?> _prevPrices = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchAll();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _fetchAll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    for (final sym in _symbols) {
      try {
        final data = await ApiService.instance.getPrice(sym);
        if (mounted) {
          setState(() {
            _prevPrices[sym] = _prices[sym];
            _prices[sym]     = data['price'] as double?;
          });
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        itemCount: _symbols.length,
        itemBuilder: (_, i) {
          final sym   = _symbols[i];
          final price = _prices[sym];
          final prev  = _prevPrices[sym];
          final isUp  = prev == null || price == null || price >= prev;
          return _PriceTile(symbol: sym, price: price, isUp: isUp)
              .animate()
              .fadeIn(duration: 300.ms, delay: Duration(milliseconds: i * 80));
        },
      ),
    );
  }
}

class _PriceTile extends StatelessWidget {
  final String symbol;
  final double? price;
  final bool isUp;

  const _PriceTile({required this.symbol, required this.price, required this.isUp});

  @override
  Widget build(BuildContext context) {
    final color = isUp ? AppTheme.green : AppTheme.red;

    return Container(
      margin: EdgeInsets.only(right: 8.w),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 10.sp, color: color),
            SizedBox(width: 3.w),
            Text(symbol.replaceAll('USD', ''),
                style: TextStyle(color: AppTheme.textSec(context),
                    fontSize: 10.sp, fontWeight: FontWeight.w600)),
          ]),
          SizedBox(height: 2.h),
          Text(
            price != null ? price!.toStringAsFixed(2) : '---',
            style: TextStyle(color: color, fontSize: 12.sp, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
