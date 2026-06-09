import 'package:flutter/material.dart';
import '../../../core/models/alert_model.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';

class AlertCard extends StatelessWidget {
  final AlertModel alert;
  final String lang;
  final VoidCallback? onDelete;

  const AlertCard({
    super.key,
    required this.alert,
    required this.lang,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isAbove  = alert.isAbove;
    final dirColor = isAbove ? AppTheme.green : AppTheme.red;
    final dirIcon  = isAbove ? Icons.arrow_upward : Icons.arrow_downward;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: dirColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(dirIcon, color: dirColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(alert.symbol,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        )),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: dirColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(alert.direction,
                          style: TextStyle(color: dirColor, fontSize: 11)),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    '${AppStrings.t(AppStrings.target, lang)}: ${alert.targetPrice}',
                    style: const TextStyle(
                        color: AppTheme.textSecond, fontSize: 13),
                  ),
                  Text(alert.createdAt,
                      style: const TextStyle(
                          color: AppTheme.textSecond, fontSize: 11)),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppTheme.textSecond),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
