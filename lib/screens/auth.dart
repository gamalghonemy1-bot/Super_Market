import 'package:flutter/material.dart';
import '../db.dart';
import '../session.dart';
import 'dashboard.dart';

Future<Map<String, String>> _brand() async => {
      'store': await AppDb.I.getSetting('store_name'),
      'branch': await AppDb.I.getSetting('branch'),
      'manager': await AppDb.I.getSetting('manager'),
    };

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashState();
}

class _SplashState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1B5E20), Color(0xFF66BB6A)]),
          ),
          child: FutureBuilder<Map<String, String>>(
            future: _brand(),
            builder: (_, s) {
              final b = s.data ?? {};
              return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.local_grocery_store, size: 96, color: Colors.white),
                const SizedBox(height: 16),
                Text(b['store'] ?? '',
                    style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(b['branch'] ?? '', style: const TextStyle(fontSize: 20, color: Colors.white)),
                const SizedBox(height: 4),
                Text('إدارة ${b['manager'] ?? ''}', style: const TextStyle(fontSize: 16, color: Colors.white70)),
              ]);
            },
          ),
        ),
      );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final u = TextEditingController();
  final p = TextEditingController();
  bool busy = false;

  Future<void> _go() async {
    setState(() => busy = true);
    final r = await AppDb.I.login(u.text, p.text);
    if (!mounted) return;
    setState(() => busy = false);
    if (r == null) {
      toast(context, 'اسم المستخدم أو كلمة المرور غير صحيحة');
      return;
    }
    Session.user = r;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(children: [
                FutureBuilder<Map<String, String>>(
                  future: _brand(),
                  builder: (_, s) => Column(children: [
                    Icon(Icons.local_grocery_store, size: 72, color: Theme.of(context).colorScheme.primary),
                    Text(s.data?['store'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text('${s.data?['branch'] ?? ''} - إدارة ${s.data?['manager'] ?? ''}'),
                  ]),
                ),
                const SizedBox(height: 32),
                TextField(
                    controller: u,
                    decoration: const InputDecoration(labelText: 'اسم المستخدم', prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: p,
                    obscureText: true,
                    onSubmitted: (_) => _go(),
                    decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock), border: OutlineInputBorder())),
                const SizedBox(height: 20),
                SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(onPressed: busy ? null : _go, child: const Text('تسجيل الدخول'))),
              ]),
            ),
          ),
        ),
      );
}
