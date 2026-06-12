import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/models/alert_model.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';

class AlertCard extends StatelessWidget {
  final AlertModel alert;
  final String lang;
  final VoidCallback? onDelete;
  final bool isTriggered;

  const AlertCard({
    super.key,
    required this.alert,
    required this.lang,
    this.onDelete,
    this.isTriggered = false,
  });

  @override
  Widget build(BuildContext context) {
    final isAbove  = alert.isAbove;
    final dirColor = isAbove ? AppTheme.green : AppTheme.red;
    final dirIcon  = isAbove
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTriggered
              ? AppTheme.green.withOpacity(0.4)
              : AppTheme.border,
        ),
        boxShadow: isTriggered
            ? [
                BoxShadow(
                  color: AppTheme.green.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // ── آیکون جهت ─────────────────────────────────────────
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    dirColor.withOpacity(0.2),
                    dirColor.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: dirColor.withOpacity(0.3)),
              ),
              child: Icon(dirIcon, color: dirColor, size: 22),
            ),
            const SizedBox(width: 14),

            // ── اطلاعات ────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        alert.symbol,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: dirColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: dirColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          alert.direction,
                          style: TextStyle(
                              color: dirColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (isTriggered) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '✓ Hit',
                            style: TextStyle(
                                color: AppTheme.green,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.flag_rounded,
                        label:
                            '${AppStrings.t(AppStrings.target, lang)}: ${_formatPrice(alert.targetPrice)}',
                        color: AppTheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isTriggered && alert.triggeredAt != null
                        ? alert.triggeredAt!
                        : alert.createdAt,
                    style: const TextStyle(
                        color: AppTheme.textHint, fontSize: 11),
                  ),
                ],
              ),
            ),

            // ── دکمه حذف ──────────────────────────────────────────
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppTheme.textSecond, size: 20),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000) return price.toStringAsFixed(2);
    if (price >= 10)   return price.toStringAsFixed(4);
    return price.toStringAsFixed(5);
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              color: color.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
