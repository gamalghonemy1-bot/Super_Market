import 'package:flutter/material.dart';
import '../db.dart';
import '../session.dart';
import 'auth.dart';
import 'cashier.dart';
import 'invoices.dart';
import 'products.dart';
import 'settings.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashState();
}

class _DashState extends State<DashboardScreen> {
  late Future<Map<String, double>> f = AppDb.I.dashboard();

  Future<void> _open(Widget w) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    setState(() => f = AppDb.I.dashboard());
  }

  Widget _stat(String t, String v, IconData i, Color c) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(i, color: c),
            const SizedBox(height: 6),
            Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(t, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
          ]),
        ),
      );

  Widget _nav(String t, IconData i, Widget w) => FilledButton.tonalIcon(
      onPressed: () => _open(w), icon: Icon(i), label: Text(t));

  @override
  Widget build(BuildContext context) {
    final admin = Session.isAdmin;
    return Scaffold(
      appBar: AppBar(
        title: Text('أهلاً ${Session.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Session.user = null;
              Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          )
        ],
      ),
      body: FutureBuilder<Map<String, double>>(
        future: f,
        builder: (_, s) {
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final d = s.data!;
          return ListView(padding: const EdgeInsets.all(12), children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.6,
              children: [
                _stat('مبيعات اليوم (ج.م)', fmt(d['sales']!), Icons.point_of_sale, Colors.green),
                if (admin) _stat('أرباح اليوم (ج.م)', fmt(d['profit']!), Icons.trending_up, Colors.teal),
                _stat('عدد الفواتير', fmt(d['count']!), Icons.receipt_long, Colors.blue),
                if (admin) _stat('مشتريات اليوم', fmt(d['purchases']!), Icons.shopping_cart, Colors.orange),
                if (admin) _stat('قيمة المخزون', fmt(d['stockValue']!), Icons.inventory_2, Colors.indigo),
                _stat('أصناف منخفضة', fmt(d['low']!), Icons.warning_amber, Colors.amber),
                _stat('أصناف نافدة', fmt(d['out']!), Icons.error_outline, Colors.red),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _nav('الكاشير', Icons.point_of_sale, const CashierScreen()),
              _nav('الأصناف والمخزون', Icons.inventory, const ProductsScreen()),
              _nav('الفواتير', Icons.receipt_long, const InvoicesScreen()),
              _nav('الإعدادات', Icons.settings, const SettingsScreen()),
            ]),
          ]);
        },
      ),
    );
  }
}
