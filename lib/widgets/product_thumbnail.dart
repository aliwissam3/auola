import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';

/// A small circular product photo — falls back to a friendly pill/medicine
/// icon (colored circle) when the product has no photo set, instead of a
/// blank avatar, so the products list and POS search results never look
/// empty even before someone gets around to photographing everything.
class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({super.key, required this.product, this.radius = 20});

  final Product product;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final img = product.image;
    if (img != null && img.isNotEmpty) {
      try {
        return CircleAvatar(radius: radius, backgroundImage: MemoryImage(base64Decode(img)));
      } catch (_) {
        // Fall through to the placeholder if the stored data is corrupt.
      }
    }
    final accent = Theme.of(context).extension<AppPaletteColors>()?.primary ??
        Theme.of(context).colorScheme.primary;
    return CircleAvatar(
      radius: radius,
      backgroundColor: accent.withValues(alpha: 0.12),
      child: Icon(Icons.medication_rounded, color: accent, size: radius),
    );
  }
}
