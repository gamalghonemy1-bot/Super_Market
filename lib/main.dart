import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'db.dart';
import 'screens/auth.dart';

final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  themeMode.value =
      (await AppDb.I.getSetting('dark')) == '1' ? ThemeMode.dark : ThemeMode.light;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2E7D32);
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (_, m, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'سوبر ماركت الريف المصري',
        locale: const Locale('ar', 'EG'),
        supportedLocales: const [Locale('ar', 'EG')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        themeMode: m,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: seed),
        darkTheme: ThemeData(
            useMaterial3: true, brightness: Brightness.dark, colorSchemeSeed: seed),
        home: const SplashScreen(),
      ),
    );
  }
}
