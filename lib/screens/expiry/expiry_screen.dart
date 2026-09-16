import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_data.dart';
import '../../services/settings_service.dart';
import '../../widgets/sale_shortcut_action.dart';

class ExpiryScreen extends StatelessWidget {
  const ExpiryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final settings = context.watch<SettingsService>();
    final batches = data.expiringBatches(withinDays: settings.expiryAlertDays);

    return Scaffold(
      appBar: AppBar(
        title: Text('الإكسباير القريب (${batches.length})'),
        actions: [
          const SaleShortcutAction(),
          IconButton(
            tooltip: 'مدة التنبيه (${settings.expiryAlertDays} يوم) — من الإعدادات',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: batches.isEmpty
          ? Center(
              child: Text('لا توجد مواد ستنتهي خلال ${settings.expiryAlertDays} يوم'),
            )
          : ListView.separated(
              itemCount: batches.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final b = batches[i];
                final product = data.products.byId(b.productId);
                final days = b.expiryDate!.difference(DateTime.now()).inDays;
                final urgent = days <= 30;
                return ListTile(
                  leading: Icon(Icons.event_busy, color: urgent ? Colors.red : Colors.orange),
                  title: Text(product?.name ?? 'مادة محذوفة'),
                  subtitle: Text('الكمية: ${b.quantity} • رقم الدفعة: ${b.batchNumber ?? '—'}'),
                  trailing: Text(
                    '${b.expiryDate!.year}/${b.expiryDate!.month}/${b.expiryDate!.day}\n${days >= 0 ? 'باقي $days يوم' : 'منتهي منذ ${-days} يوم'}',
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: urgent ? Colors.red : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
