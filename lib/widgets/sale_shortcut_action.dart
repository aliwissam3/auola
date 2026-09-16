import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

/// A small "بيع" button meant to sit in a screen's AppBar (next to its
/// title), not floating over the content — so it never covers anything
/// on screen, including the Android back/gesture area at the bottom.
/// Hidden entirely for anyone without sales permission.
class SaleShortcutAction extends StatelessWidget {
  const SaleShortcutAction({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.isLoggedIn || !auth.can((p) => p.sales)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: ElevatedButton.icon(
        onPressed: () => Navigator.of(context).pushNamed('/pos'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE0407A),
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: const Icon(Icons.point_of_sale, size: 18),
        label: const Text('بيع', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
