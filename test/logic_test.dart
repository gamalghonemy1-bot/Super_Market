import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rif_market/db.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    await AppDb.I.reset();
    AppDb.testPath = inMemoryDatabasePath;
  });

  Future<int> addProduct({double qty = 100}) async {
    await AppDb.I.saveProduct({
      'name': 'سكر', 'barcode': '111', 'unit': 'كيلو',
      'cost_price': 10.0, 'sell_price': 15.0, 'qty': qty, 'min_qty': 5.0
    }, 1);
    return (await AppDb.I.productByBarcode('111'))!['id'] as int;
  }

  test('admin login works and wrong password fails', () async {
    expect(await AppDb.I.login('admin', 'admin123'), isNotNull);
    expect(await AppDb.I.login('admin', 'x'), isNull);
  });

  test('sale updates stock and profit uses cost at sale time', () async {
    final id = await addProduct();
    await AppDb.I.createSale(
        lines: [CartLine(id, 'سكر', 3, 15)], discount: 0, paid: 45, method: 'cash', userId: 1);
    var p = (await AppDb.I.productByBarcode('111'))!;
    expect(p['qty'], 97);
    var dash = await AppDb.I.dashboard();
    expect(dash['sales'], 45);
    expect(dash['profit'], 15);
    // change cost later: old profit must not change
    await AppDb.I.saveProduct({
      'id': id, 'name': 'سكر', 'barcode': '111', 'unit': 'كيلو',
      'cost_price': 12.0, 'sell_price': 15.0, 'qty': 97.0, 'min_qty': 5.0
    }, 1);
    dash = await AppDb.I.dashboard();
    expect(dash['profit'], 15);
  });

  test('insufficient stock rolls back everything', () async {
    final id = await addProduct(qty: 2);
    expect(
        () => AppDb.I.createSale(
            lines: [CartLine(id, 'سكر', 5, 15)], discount: 0, paid: 75, method: 'cash', userId: 1),
        throwsException);
    expect((await AppDb.I.sales()).length, 0);
    expect((await AppDb.I.productByBarcode('111'))!['qty'], 2);
  });

  test('cancel restores stock and removes from totals', () async {
    final id = await addProduct();
    final sid = await AppDb.I.createSale(
        lines: [CartLine(id, 'سكر', 4, 15)], discount: 5, paid: 55, method: 'cash', userId: 1);
    await AppDb.I.cancelSale(sid, 'خطأ', 1);
    expect((await AppDb.I.productByBarcode('111'))!['qty'], 100);
    final dash = await AppDb.I.dashboard();
    expect(dash['sales'], 0);
    expect(dash['profit'], 0);
  });
}
