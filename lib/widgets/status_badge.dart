import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// A small soft-tint pill used everywhere a status needs to read at a
/// glance: stock level ("منتهي" / "منخفض" / "متوفر"), expiry alerts, or
/// payment state ("مسدد" / "متأخر"). Backed by [AppStatusTone] so every
/// screen in the app uses the exact same five colors instead of each
/// screen inventing its own reds and greens.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = AppStatusTone.neutral,
    this.icon,
    this.dense = false,
  });

  final String label;
  final AppStatusTone tone;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final fg = AppStatusColors.foreground(tone);
    final bg = AppStatusColors.background(tone);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: dense ? 11 : 12.5,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
