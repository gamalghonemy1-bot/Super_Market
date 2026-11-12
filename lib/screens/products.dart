import 'package:flutter/material.dart';
import '../db.dart';
import '../session.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsState();
}

class _ProductsState extends State<ProductsScreen> {
  String q = '';
  List<Map<String, Object?>> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await AppDb.I.products(q);
    if (mounted) setState(() => items = r);
  }

  Future<void> _edit([Map<String, Object?>? p]) async {
    String s(String k) => (p?[k] ?? '').toString();
    String n(String k) => p == null ? '' : fmt((p[k] as num));
    final c = {
      'name': TextEditingController(text: s('name')),
      'code': TextEditingController(text: s('code')),
      'barcode': TextEditingController(text: s('barcode')),
      'unit': TextEditingController(text: p == null ? 'قطعة' : s('unit')),
      'cost': TextEditingController(text: n('cost_price')),
      'sell': TextEditingController(text: n('sell_price')),
      'qty': TextEditingController(text: n('qty')),
      'min': TextEditingController(text: n('min_qty')),
      'exp': TextEditingController(text: s('expiry_date')),
    };
    Widget f(String k, String label, {bool num = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(
            controller: c[k],
            keyboardType: num ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
          ),
        );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(p == null ? 'إضافة صنف' : 'تعديل صنف'),
        content: SingleChildScrollView(
          child: Column(children: [
            f('name', 'اسم الصنف'),
            f('code', 'كود الصنف'),
            f('barcode', 'الباركود'),
            f('unit', 'وحدة القياس'),
            f('cost', 'سعر الشراء', num: true),
            f('sell', 'سعر البيع', num: true),
            f('qty', 'الكمية المتاحة', num: true),
            f('min', 'الحد الأدنى للمخزون', num: true),
            f('exp', 'تاريخ الصلاحية (YYYY-MM-DD)'),
          ]),
        ),
        actions: [
          if (p != null)
            TextButton(
              onPressed: () async {
                try {
                  await AppDb.I.deleteProduct(p['id'] as int, Session.id);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) toast(ctx, errText(e));
                }
              },
              child: const Text('حذف', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              try {
                await AppDb.I.saveProduct({
                  if (p != null) 'id': p['id'],
                  'name': c['name']!.text.trim(),
                  'code': c['code']!.text.trim(),
                  'barcode': c['barcode']!.text.trim(),
                  'unit': c['unit']!.text.trim(),
                  'cost_price': toD(c['cost']!.text),
                  'sell_price': toD(c['sell']!.text),
                  'qty': toD(c['qty']!.text),
                  'min_qty': toD(c['min']!.text),
                  'expiry_date': c['exp']!.text.trim(),
                }, Session.id);
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) toast(ctx, errText(e));
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final admin = Session.isAdmin;
    return Scaffold(
      appBar: AppBar(title: const Text('الأصناف والمخزون')),
      floatingActionButton:
          admin ? FloatingActionButton(onPressed: () => _edit(), child: const Icon(Icons.add)) : null,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            onChanged: (v) {
              q = v;
              _load();
            },
            decoration: const InputDecoration(
                hintText: 'بحث بالاسم أو الباركود', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('لا توجد أصناف'))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final p = items[i];
                    final qty = (p['qty'] as num).toDouble();
                    final low = qty <= (p['min_qty'] as num).toDouble();
                    return ListTile(
                      title: Text(p['name'] as String),
                      subtitle: Text(
                          'البيع: ${fmt(p['sell_price'] as num)} | المتاح: ${fmt(qty)} ${p['unit'] ?? ''}'
                          '${admin ? ' | التكلفة: ${fmt(p['cost_price'] as num)}' : ''}'),
                      trailing: low
                          ? Icon(qty <= 0 ? Icons.error : Icons.warning_amber,
                              color: qty <= 0 ? Colors.red : Colors.amber)
                          : null,
                      onTap: admin ? () => _edit(p) : null,
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
