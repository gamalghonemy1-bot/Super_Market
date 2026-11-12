import 'package:flutter/material.dart';
import '../db.dart';
import '../session.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});
  @override
  State<CashierScreen> createState() => _CashierState();
}

class _CashierState extends State<CashierScreen> {
  final search = TextEditingController();
  final discount = TextEditingController();
  final paid = TextEditingController();
  final List<CartLine> cart = [];
  final Map<int, double> stock = {};
  List<Map<String, Object?>> results = [];
  String method = 'نقدي';

  double get subtotal => cart.fold(0.0, (a, l) => a + l.total);
  double get total => subtotal - toD(discount.text);

  Future<void> _search(String v) async {
    final r = v.trim().isEmpty ? <Map<String, Object?>>[] : await AppDb.I.products(v);
    if (mounted) setState(() => results = r.take(6).toList());
  }

  void _add(Map<String, Object?> p) {
    final id = p['id'] as int;
    final avail = (p['qty'] as num).toDouble();
    if (avail <= 0) {
      toast(context, 'الصنف نافد: ${p['name']}');
      return;
    }
    stock[id] = avail;
    final i = cart.indexWhere((l) => l.productId == id);
    setState(() {
      if (i >= 0) {
        if (cart[i].qty + 1 > avail) {
          toast(context, 'لا توجد كمية كافية');
        } else {
          cart[i].qty += 1;
        }
      } else {
        cart.add(CartLine(id, p['name'] as String, 1, (p['sell_price'] as num).toDouble()));
      }
      search.clear();
      results = [];
    });
  }

  Future<void> _onSubmit(String v) async {
    final b = await AppDb.I.productByBarcode(v);
    if (b != null) return _add(b);
    if (results.length == 1) return _add(results.first);
    if (mounted) toast(context, 'لم يتم العثور على الصنف');
  }

  Future<void> _editQty(CartLine l) async {
    final v = await askText(context, 'الكمية', initial: fmt(l.qty));
    if (v == null) return;
    final q = toD(v);
    if (q <= 0) return;
    if (q > (stock[l.productId] ?? 0)) {
      if (mounted) toast(context, 'المتاح ${fmt(stock[l.productId] ?? 0)} فقط');
      return;
    }
    setState(() => l.qty = q);
  }

  Future<void> _editPrice(CartLine l) async {
    if (!Session.isAdmin) {
      toast(context, 'تعديل السعر للمدير فقط');
      return;
    }
    final v = await askText(context, 'السعر', initial: fmt(l.price));
    if (v == null) return;
    setState(() => l.price = toD(v));
  }

  Future<void> _save() async {
    try {
      final t = total;
      final p = paid.text.trim().isEmpty ? t : toD(paid.text);
      final id = await AppDb.I.createSale(
          lines: cart, discount: toD(discount.text), paid: p, method: method, userId: Session.id);
      if (!mounted) return;
      setState(() {
        cart.clear();
        discount.clear();
        paid.clear();
      });
      toast(context, 'تم حفظ الفاتورة رقم $id');
    } catch (e) {
      if (mounted) toast(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الكاشير')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: search,
              onChanged: _search,
              onSubmitted: _onSubmit,
              decoration: const InputDecoration(
                  hintText: 'ابحث بالاسم أو امسح الباركود',
                  prefixIcon: Icon(Icons.qr_code_scanner),
                  border: OutlineInputBorder()),
            ),
          ),
          if (results.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final r in results)
                    ListTile(
                      dense: true,
                      title: Text(r['name'] as String),
                      subtitle: Text('${fmt(r['sell_price'] as num)} ج.م | المتاح ${fmt(r['qty'] as num)}'),
                      onTap: () => _add(r),
                    )
                ],
              ),
            ),
          Expanded(
            child: cart.isEmpty
                ? const Center(child: Text('الفاتورة فارغة'))
                : ListView.builder(
                    itemCount: cart.length,
                    itemBuilder: (_, i) {
                      final l = cart[i];
                      return ListTile(
                        title: Text(l.name),
                        subtitle: Text('${fmt(l.price)} × ${fmt(l.qty)} = ${fmt(l.total)}'),
                        onLongPress: () => _editPrice(l),
                        leading: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => setState(() => cart.removeAt(i))),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => setState(() {
                                    if (l.qty > 1) l.qty -= 1;
                                  })),
                          InkWell(onTap: () => _editQty(l), child: Text(fmt(l.qty), style: const TextStyle(fontSize: 16))),
                          IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => setState(() {
                                    if (l.qty + 1 <= (stock[l.productId] ?? 0)) {
                                      l.qty += 1;
                                    } else {
                                      toast(context, 'لا توجد كمية كافية');
                                    }
                                  })),
                        ]),
                      );
                    },
                  ),
          ),
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                        controller: discount,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'الخصم', isDense: true, border: OutlineInputBorder())),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                        controller: paid,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'المدفوع (فارغ = الكل)', isDense: true, border: OutlineInputBorder())),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: method,
                    items: const [
                      DropdownMenuItem(value: 'نقدي', child: Text('نقدي')),
                      DropdownMenuItem(value: 'إلكتروني', child: Text('إلكتروني')),
                    ],
                    onChanged: (v) => setState(() => method = v!),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Text('الإجمالي: ${fmt(total)} ج.م', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  FilledButton.icon(
                      onPressed: cart.isEmpty ? null : _save,
                      icon: const Icon(Icons.check),
                      label: const Text('حفظ الفاتورة')),
                ]),
              ]),
            ),
          ),
        ]),
      );
}
