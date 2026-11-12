import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

String nowStr() => DateTime.now().toString().substring(0, 19);

class CartLine {
  final int productId;
  final String name;
  double qty;
  double price;
  CartLine(this.productId, this.name, this.qty, this.price);
  double get total => qty * price;
}

const _schema = <String>[
  'CREATE TABLE users(id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT UNIQUE NOT NULL, password_hash TEXT NOT NULL, full_name TEXT, role TEXT NOT NULL, active INTEGER NOT NULL DEFAULT 1)',
  'CREATE TABLE categories(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE NOT NULL)',
  'CREATE TABLE suppliers(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT, address TEXT)',
  "CREATE TABLE products(id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT, name TEXT NOT NULL, barcode TEXT UNIQUE, category_id INTEGER, unit TEXT DEFAULT 'قطعة', cost_price REAL NOT NULL DEFAULT 0, sell_price REAL NOT NULL DEFAULT 0, qty REAL NOT NULL DEFAULT 0, min_qty REAL NOT NULL DEFAULT 0, supplier_id INTEGER, expiry_date TEXT, created_at TEXT)",
  "CREATE TABLE sales(id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER, subtotal REAL, discount REAL, total REAL, paid REAL, remaining REAL, method TEXT, status TEXT NOT NULL DEFAULT 'active', cancel_reason TEXT, cancelled_by INTEGER, created_at TEXT)",
  'CREATE TABLE sale_items(id INTEGER PRIMARY KEY AUTOINCREMENT, sale_id INTEGER NOT NULL, product_id INTEGER NOT NULL, name TEXT, qty REAL, price REAL, cost_price REAL, FOREIGN KEY(sale_id) REFERENCES sales(id), FOREIGN KEY(product_id) REFERENCES products(id))',
  'CREATE TABLE stock_movements(id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER NOT NULL, type TEXT, qty REAL, ref_id INTEGER, note TEXT, user_id INTEGER, created_at TEXT)',
  'CREATE TABLE purchases(id INTEGER PRIMARY KEY AUTOINCREMENT, supplier_id INTEGER, total REAL, paid REAL, remaining REAL, user_id INTEGER, created_at TEXT)',
  'CREATE TABLE purchase_items(id INTEGER PRIMARY KEY AUTOINCREMENT, purchase_id INTEGER, product_id INTEGER, qty REAL, cost_price REAL)',
  'CREATE TABLE expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, amount REAL, user_id INTEGER, created_at TEXT)',
  'CREATE TABLE treasury(id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT, amount REAL, note TEXT, user_id INTEGER, created_at TEXT)',
  'CREATE TABLE returns(id INTEGER PRIMARY KEY AUTOINCREMENT, sale_id INTEGER, reason TEXT, total REAL, user_id INTEGER, created_at TEXT)',
  'CREATE TABLE return_items(id INTEGER PRIMARY KEY AUTOINCREMENT, return_id INTEGER, product_id INTEGER, qty REAL, price REAL, cost_price REAL, restock INTEGER)',
  'CREATE TABLE audit_log(id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER, action TEXT, details TEXT, created_at TEXT)',
  'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)',
];

class AppDb {
  AppDb._();
  static final AppDb I = AppDb._();
  static String? testPath;
  Database? _db;

  static String hash(String p) =>
      sha256.convert(utf8.encode('rif_v1:$p')).toString();

  Future<Database> get db async => _db ??= await _open();

  Future<void> reset() async {
    await _db?.close();
    _db = null;
  }

  Future<Database> _open() async {
    final path = testPath ?? join(await getDatabasesPath(), 'rif_market.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (d) async => await d.execute('PRAGMA foreign_keys = ON'),
      onCreate: (d, v) async {
        for (final s in _schema) {
          await d.execute(s);
        }
        await d.insert('users', {
          'username': 'admin',
          'password_hash': hash('admin123'),
          'full_name': 'أستاذ يوسف',
          'role': 'admin',
          'active': 1
        });
        final defaults = {
          'store_name': 'سوبر ماركت الريف المصري',
          'branch': 'فرع العاصمة',
          'manager': 'أستاذ يوسف',
          'dark': '0'
        };
        for (final e in defaults.entries) {
          await d.insert('settings', {'key': e.key, 'value': e.value});
        }
      },
    );
  }

  Future<String> getSetting(String k) async {
    final d = await db;
    final r = await d.query('settings', where: 'key=?', whereArgs: [k]);
    return r.isEmpty ? '' : (r.first['value'] as String? ?? '');
  }

  Future<void> setSetting(String k, String v) async {
    final d = await db;
    await d.insert('settings', {'key': k, 'value': v},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> audit(int? uid, String action, String details) async {
    final d = await db;
    await d.insert('audit_log', {
      'user_id': uid,
      'action': action,
      'details': details,
      'created_at': nowStr()
    });
  }

  Future<Map<String, Object?>?> login(String u, String p) async {
    final d = await db;
    final r = await d.query('users',
        where: 'username=? AND password_hash=? AND active=1',
        whereArgs: [u.trim(), hash(p)]);
    if (r.isEmpty) return null;
    await audit(r.first['id'] as int, 'login', u);
    return r.first;
  }

  Future<List<Map<String, Object?>>> users() async =>
      (await db).query('users', orderBy: 'id');

  Future<void> addUser(String u, String p, String name, String role) async {
    if (u.trim().isEmpty || p.length < 4) {
      throw Exception('اسم المستخدم مطلوب وكلمة المرور 4 أحرف على الأقل');
    }
    try {
      await (await db).insert('users', {
        'username': u.trim(),
        'password_hash': hash(p),
        'full_name': name,
        'role': role,
        'active': 1
      });
    } on DatabaseException {
      throw Exception('اسم المستخدم موجود بالفعل');
    }
  }

  Future<void> setPassword(int id, String p) async {
    if (p.length < 4) throw Exception('كلمة المرور 4 أحرف على الأقل');
    await (await db).update('users', {'password_hash': hash(p)},
        where: 'id=?', whereArgs: [id]);
  }

  Future<void> setActive(int id, bool a) async => (await db)
      .update('users', {'active': a ? 1 : 0}, where: 'id=?', whereArgs: [id]);

  Future<List<Map<String, Object?>>> products([String q = '']) async {
    final d = await db;
    if (q.trim().isEmpty) return d.query('products', orderBy: 'name');
    final like = '%${q.trim()}%';
    return d.query('products',
        where: 'name LIKE ? OR barcode LIKE ? OR code LIKE ?',
        whereArgs: [like, like, like],
        orderBy: 'name',
        limit: 50);
  }

  Future<Map<String, Object?>?> productByBarcode(String b) async {
    final r = await (await db)
        .query('products', where: 'barcode=?', whereArgs: [b.trim()]);
    return r.isEmpty ? null : r.first;
  }

  Future<void> saveProduct(Map<String, Object?> p, int uid) async {
    if ((p['name'] as String).trim().isEmpty) throw Exception('اسم الصنف مطلوب');
    if ((p['barcode'] as String?)?.trim().isEmpty ?? true) p['barcode'] = null;
    final d = await db;
    try {
      await d.transaction((t) async {
        final id = p['id'] as int?;
        final newQty = (p['qty'] as num).toDouble();
        if (id == null) {
          p.remove('id');
          p['created_at'] = nowStr();
          final nid = await t.insert('products', p);
          if (newQty != 0) {
            await t.insert('stock_movements', {
              'product_id': nid, 'type': 'opening', 'qty': newQty,
              'note': 'رصيد افتتاحي', 'user_id': uid, 'created_at': nowStr()
            });
          }
          await t.insert('audit_log', {'user_id': uid, 'action': 'product_add', 'details': '${p['name']}', 'created_at': nowStr()});
        } else {
          final old = await t.query('products', where: 'id=?', whereArgs: [id]);
          final oldQty = (old.first['qty'] as num).toDouble();
          await t.update('products', p, where: 'id=?', whereArgs: [id]);
          if (oldQty != newQty) {
            await t.insert('stock_movements', {
              'product_id': id, 'type': 'adjust', 'qty': newQty - oldQty,
              'note': 'تعديل يدوي', 'user_id': uid, 'created_at': nowStr()
            });
          }
          await t.insert('audit_log', {'user_id': uid, 'action': 'product_edit', 'details': '${p['name']}', 'created_at': nowStr()});
        }
      });
    } on DatabaseException {
      throw Exception('الباركود مستخدم لصنف آخر');
    }
  }

  Future<void> deleteProduct(int id, int uid) async {
    final d = await db;
    final used = await d.query('sale_items',
        where: 'product_id=?', whereArgs: [id], limit: 1);
    if (used.isNotEmpty) {
      throw Exception('لا يمكن حذف صنف عليه حركات بيع');
    }
    await d.transaction((t) async {
      await t.delete('stock_movements', where: 'product_id=?', whereArgs: [id]);
      await t.delete('products', where: 'id=?', whereArgs: [id]);
      await t.insert('audit_log', {'user_id': uid, 'action': 'product_delete', 'details': '$id', 'created_at': nowStr()});
    });
  }

  Future<int> createSale({
    required List<CartLine> lines,
    required double discount,
    required double paid,
    required String method,
    required int userId,
  }) async {
    if (lines.isEmpty) throw Exception('الفاتورة فارغة');
    final d = await db;
    return d.transaction<int>((t) async {
      double subtotal = 0;
      final costs = <int, double>{};
      for (final l in lines) {
        if (l.qty <= 0 || l.price < 0) throw Exception('كمية أو سعر غير صحيح: ${l.name}');
        final r = await t.query('products', where: 'id=?', whereArgs: [l.productId]);
        if (r.isEmpty) throw Exception('الصنف غير موجود: ${l.name}');
        final stock = (r.first['qty'] as num).toDouble();
        if (stock < l.qty) throw Exception('الكمية غير كافية للصنف ${l.name} (المتاح $stock)');
        costs[l.productId] = (r.first['cost_price'] as num).toDouble();
        subtotal += l.total;
      }
      if (discount < 0 || discount > subtotal) throw Exception('قيمة الخصم غير صحيحة');
      final total = subtotal - discount;
      final remaining = math.max(0.0, total - paid);
      final sid = await t.insert('sales', {
        'user_id': userId, 'subtotal': subtotal, 'discount': discount,
        'total': total, 'paid': paid, 'remaining': remaining,
        'method': method, 'status': 'active', 'created_at': nowStr()
      });
      for (final l in lines) {
        await t.insert('sale_items', {
          'sale_id': sid, 'product_id': l.productId, 'name': l.name,
          'qty': l.qty, 'price': l.price, 'cost_price': costs[l.productId]
        });
        await t.rawUpdate('UPDATE products SET qty = qty - ? WHERE id=?', [l.qty, l.productId]);
        await t.insert('stock_movements', {
          'product_id': l.productId, 'type': 'sale', 'qty': -l.qty,
          'ref_id': sid, 'user_id': userId, 'created_at': nowStr()
        });
      }
      await t.insert('audit_log', {'user_id': userId, 'action': 'sale', 'details': 'فاتورة $sid بإجمالي $total', 'created_at': nowStr()});
      return sid;
    });
  }

  Future<void> cancelSale(int saleId, String reason, int userId) async {
    if (reason.trim().isEmpty) throw Exception('سبب الإلغاء مطلوب');
    final d = await db;
    await d.transaction((t) async {
      final s = await t.query('sales', where: 'id=?', whereArgs: [saleId]);
      if (s.isEmpty || s.first['status'] != 'active') throw Exception('الفاتورة ملغاة بالفعل');
      await t.update('sales', {'status': 'cancelled', 'cancel_reason': reason, 'cancelled_by': userId}, where: 'id=?', whereArgs: [saleId]);
      final items = await t.query('sale_items', where: 'sale_id=?', whereArgs: [saleId]);
      for (final i in items) {
        await t.rawUpdate('UPDATE products SET qty = qty + ? WHERE id=?', [i['qty'], i['product_id']]);
        await t.insert('stock_movements', {
          'product_id': i['product_id'], 'type': 'cancel', 'qty': i['qty'],
          'ref_id': saleId, 'note': reason, 'user_id': userId, 'created_at': nowStr()
        });
      }
      await t.insert('audit_log', {'user_id': userId, 'action': 'sale_cancel', 'details': 'فاتورة $saleId: $reason', 'created_at': nowStr()});
    });
  }

  Future<List<Map<String, Object?>>> sales() async => (await db).rawQuery(
      'SELECT s.*, u.full_name AS user_name FROM sales s LEFT JOIN users u ON u.id=s.user_id ORDER BY s.id DESC LIMIT 200');

  Future<List<Map<String, Object?>>> saleItems(int id) async =>
      (await db).query('sale_items', where: 'sale_id=?', whereArgs: [id]);

  Future<Map<String, double>> dashboard() async {
    final d = await db;
    final today = nowStr().substring(0, 10);
    double v(List<Map<String, Object?>> r, String k) =>
        ((r.first[k] ?? 0) as num).toDouble();
    final s = await d.rawQuery(
        "SELECT COALESCE(SUM(total),0) t, COUNT(*) c, COALESCE(SUM(discount),0) disc FROM sales WHERE status='active' AND date(created_at)=?",
        [today]);
    final p = await d.rawQuery(
        "SELECT COALESCE(SUM((si.price-si.cost_price)*si.qty),0) g FROM sale_items si JOIN sales s ON s.id=si.sale_id WHERE s.status='active' AND date(s.created_at)=?",
        [today]);
    final st = await d.rawQuery(
        'SELECT COALESCE(SUM(qty*cost_price),0) val, '
        'COALESCE(SUM(CASE WHEN qty<=0 THEN 1 ELSE 0 END),0) outc, '
        'COALESCE(SUM(CASE WHEN qty>0 AND qty<=min_qty THEN 1 ELSE 0 END),0) lowc FROM products');
    final pu = await d.rawQuery(
        'SELECT COALESCE(SUM(total),0) t FROM purchases WHERE date(created_at)=?', [today]);
    return {
      'sales': v(s, 't'),
      'count': v(s, 'c'),
      'profit': v(p, 'g') - v(s, 'disc'),
      'stockValue': v(st, 'val'),
      'out': v(st, 'outc'),
      'low': v(st, 'lowc'),
      'purchases': v(pu, 't'),
    };
  }
}
