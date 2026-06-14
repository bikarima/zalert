import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Reusable shimmer loading components.
/// Use wherever data is being fetched to replace empty/placeholder states.

// ── Base box ──────────────────────────────────────────────────────────────────

class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor:  isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
      highlightColor: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

// ── Market price card shimmer ────────────────────────────────────────────────

class ShimmerMarketCard extends StatelessWidget {
  const ShimmerMarketCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor:  isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
      highlightColor: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5),
      child: Container(
        width: 160.w,
        height: 100.h,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(16.r),
        ),
        padding: EdgeInsets.all(12.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 60.w, height: 12.h, decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(4.r),
            )),
            SizedBox(height: 8.h),
            Container(width: 100.w, height: 18.h, decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(4.r),
            )),
            SizedBox(height: 6.h),
            Container(width: 50.w, height: 10.h, decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(4.r),
            )),
          ],
        ),
      ),
    );
  }
}

// ── Alert list tile shimmer ───────────────────────────────────────────────────

class ShimmerAlertTile extends StatelessWidget {
  const ShimmerAlertTile({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor:  isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
      highlightColor: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Container(width: 40.w, height: 40.h, decoration: BoxDecoration(
              color: Colors.white24, shape: BoxShape.circle,
            )),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 100.w, height: 14.h, decoration: BoxDecoration(
                    color: Colors.white24, borderRadius: BorderRadius.circular(4.r),
                  )),
                  SizedBox(height: 6.h),
                  Container(width: 150.w, height: 12.h, decoration: BoxDecoration(
                    color: Colors.white24, borderRadius: BorderRadius.circular(4.r),
                  )),
                ],
              ),
            ),
            Container(width: 60.w, height: 20.h, decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(8.r),
            )),
          ],
        ),
      ),
    );
  }
}

/// Shows N shimmer tiles in a column.
class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.count = 5, this.tile = const ShimmerAlertTile()});
  final int count;
  final Widget tile;

  @override
  Widget build(BuildContext context) =>
      Column(children: List.generate(count, (_) => tile));
}
