import 'package:flutter/material.dart';

import '../../core/theme.dart';

enum StatusType { safe, warning, alert }

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusType type;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.type,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    Color textColor;
    Color borderColor;

    switch (type) {
      case StatusType.safe:
        badgeColor = AppColors.safeEmerald.withAlpha(45);
        textColor = AppColors.safeEmeraldAccent;
        borderColor = AppColors.safeEmeraldAccent.withAlpha(120);
        break;
      case StatusType.warning:
        badgeColor = AppColors.warningAmber.withAlpha(45);
        textColor = AppColors.warningAmber;
        borderColor = AppColors.warningAmber.withAlpha(120);
        break;
      case StatusType.alert:
        badgeColor = AppColors.alertBrickRed.withAlpha(45);
        textColor = AppColors.alertBrickRed;
        borderColor = AppColors.alertBrickRed.withAlpha(120);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
