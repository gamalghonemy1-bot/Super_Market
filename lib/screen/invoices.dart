import 'package:flutter/material.dart';
import '../db.dart';
import '../session.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});
  @override
  State<InvoicesScreen> createState() => _InvoicesState();
}

class _InvoicesState extends State<InvoicesScreen> {
  List<Map<String, Object?>> rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await AppDb.I.sales();
    if (mounted) setState(() => rows = r);
  }

  Future<void> _show(Map<String, Object?> s) async {
    final items = await AppDb.I.saleItems(s['id'] as int);
    if (!mounted) return;
    final cancelled = s['status'] == 'cancelled';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('فاتورة #${s['id']}${cancelled ? ' (ملغاة)' : ''}'),
        content: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final i in items) Text('${i['name']}: ${fmt(i['qty'] as num)} × ${fmt(i['price'] as num)}'),
            const Divider(),
            Text('الخصم: ${fmt(s['discount'] as num)}'),
            Text('الإجمالي: ${fmt(s['total'] as num)}'),
            Text('المدفوع: ${fmt(s['paid'] as num)} | المتبقي: ${fmt(s['remaining'] as num)}'),
            Text('الدفع: ${s['method']}'),
            if (cancelled) Text('سبب الإلغاء: ${s['cancel_reason']}'),
          ]),
        ),
        actions: [
          if (Session.isAdmin && !cancelled)
            TextButton(
              onPressed: () async {
                final r = await askText(ctx, 'سبب إلغاء الفاتورة');
                if (r == null) return;
                try {
                  await AppDb.I.cancelSale(s['id'] as int, r, Session.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  if (ctx.mounted) toast(ctx, errText(e));
                }
              },
              child: const Text('إلغاء الفاتورة', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الفواتير')),
        body: rows.isEmpty
            ? const Center(child: Text('لا توجد فواتير'))
            : ListView.builder(
                itemCount: rows.length,
                itemBuilder: (_, i) {
                  final s = rows[i];
                  final c = s['status'] == 'cancelled';
                  return ListTile(
                    title: Text('فاتورة #${s['id']} - ${fmt(s['total'] as num)} ج.م',
                        style: TextStyle(decoration: c ? TextDecoration.lineThrough : null)),
                    subtitle: Text('${s['created_at']} | ${s['user_name'] ?? ''}'),
                    onTap: () => _show(s),
                  );
                },
              ),
      );
}
