import 'package:flutter/material.dart';

class Session {
  static Map<String, Object?>? user;
  static bool get isAdmin => user?['role'] == 'admin';
  static int get id => user!['id'] as int;
  static String get name => (user?['full_name'] ?? user?['username'] ?? '') as String;
}

double toD(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  var o = s.trim().replaceAll('٫', '.').replaceAll(',', '.');
  for (var i = 0; i < 10; i++) {
    o = o.replaceAll(ar[i], '$i');
  }
  return double.tryParse(o) ?? 0;
}

String fmt(num n) =>
    n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);

void toast(BuildContext c, String m) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));
}

String errText(Object e) => e.toString().replaceFirst('Exception: ', '');

Future<String?> askText(BuildContext c, String title,
    {String hint = '', bool obscure = false, String initial = ''}) {
  final ctl = TextEditingController(text: initial);
  return showDialog<String>(
    context: c,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
          controller: ctl,
          autofocus: true,
          obscureText: obscure,
          decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(c, ctl.text), child: const Text('موافق')),
      ],
    ),
  );
}
