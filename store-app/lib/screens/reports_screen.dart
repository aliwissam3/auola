import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/backend_service.dart';

enum _Period { today, week, month, all }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _Period _period = _Period.today;

  DateTime? get _from {
    final now = DateTime.now();
    switch (_period) {
      case _Period.today:
        return DateTime(now.year, now.month, now.day);
      case _Period.week:
        return now.subtract(Duration(days: now.weekday - 1)).let((d) => DateTime(d.year, d.month, d.day));
      case _Period.month:
        return DateTime(now.year, now.month, 1);
      case _Period.all:
        return null;
    }
  }

  Future<_ReportData> _load() async {
    final from = _from;
    final summary = await BackendService.instance.getReportSummary(from: from);
    final topProducts = await BackendService.instance.getTopProducts(from: from);
    final totalDebt = await BackendService.instance.getTotalOutstandingDebt();
    final lowStock = await BackendService.instance.getLowStockProducts();
    return _ReportData(
      totalSales: summary.totalSales,
      totalProfit: summary.totalProfit,
      topProducts: topProducts,
      totalDebt: totalDebt,
      lowStock: lowStock,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('اليوم'),
                selected: _period == _Period.today,
                onSelected: (_) => setState(() => _period = _Period.today),
              ),
              ChoiceChip(
                label: const Text('هذا الأسبوع'),
                selected: _period == _Period.week,
                onSelected: (_) => setState(() => _period = _Period.week),
              ),
              ChoiceChip(
                label: const Text('هذا الشهر'),
                selected: _period == _Period.month,
                onSelected: (_) => setState(() => _period = _Period.month),
              ),
              ChoiceChip(
                label: const Text('الكل'),
                selected: _period == _Period.all,
                onSelected: (_) => setState(() => _period = _Period.all),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<_ReportData>(
            future: _load(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data!;
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'إجمالي المبيعات',
                          value: _fmt(data.totalSales),
                          icon: Icons.point_of_sale,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          title: 'صافي الربح',
                          value: _fmt(data.totalProfit),
                          icon: Icons.trending_up,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _StatCard(
                    title: 'إجمالي الديون المستحقة (كل الفترات)',
                    value: _fmt(data.totalDebt),
                    icon: Icons.credit_score,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  Text('الأكثر مبيعاً', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (data.topProducts.isEmpty)
                    const Text('لا توجد بيانات كافية')
                  else
                    Card(
                      child: Column(
                        children: data.topProducts
                            .map((e) => ListTile(
                                  leading: const Icon(Icons.star_outline, color: Colors.amber),
                                  title: Text(e.key),
                                  trailing: Text('${_fmt(e.value)} وحدة'),
                                ))
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text('تنبيه نفاد المخزون', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (data.lowStock.isEmpty)
                    const Text('لا توجد منتجات على وشك النفاد')
                  else
                    Card(
                      child: Column(
                        children: data.lowStock
                            .map((p) => ListTile(
                                  leading: const Icon(Icons.warning_amber, color: Colors.red),
                                  title: Text(p.name),
                                  trailing: Text('${_fmt(p.quantity)} ${p.unit}'),
                                ))
                            .toList(),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReportData {
  final double totalSales;
  final double totalProfit;
  final List<MapEntry<String, double>> topProducts;
  final double totalDebt;
  final List<Product> lowStock;

  _ReportData({
    required this.totalSales,
    required this.totalProfit,
    required this.topProducts,
    required this.totalDebt,
    required this.lowStock,
  });
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

String _fmt(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2);
}

extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
