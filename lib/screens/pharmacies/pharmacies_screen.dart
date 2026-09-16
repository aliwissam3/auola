import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/app_data.dart';
import '../../data/id_gen.dart';
import '../../models/people.dart';

class PharmaciesScreen extends StatelessWidget {
  const PharmaciesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    return Scaffold(
      appBar: AppBar(title: const Text('الصيدليات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDialog(context),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('إضافة صيدلية'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: data.pharmacies.items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final ph = data.pharmacies.items[i];
          final productCount = data.products.items.where((p) => p.pharmacyId == ph.id).length;
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.store_mall_directory_outlined)),
            title: Text(ph.name),
            subtitle: Text(ph.address.isEmpty ? 'بدون عنوان' : ph.address),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$productCount مادة'),
                IconButton(
                  tooltip: 'تعديل الاسم',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _addDialog(context, existing: ph),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addDialog(BuildContext context, {Pharmacy? existing}) async {
    final data = context.read<AppData>();
    final name = TextEditingController(text: existing?.name ?? '');
    final address = TextEditingController(text: existing?.address ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'إضافة صيدلية' : 'تعديل الصيدلية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
            TextField(controller: address, decoration: const InputDecoration(labelText: 'العنوان')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              await data.pharmacies.upsert(Pharmacy(
                id: existing?.id ?? newId(),
                name: name.text.trim(),
                address: address.text.trim(),
              ));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
