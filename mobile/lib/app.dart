import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';

class WaselApp extends StatelessWidget {
  const WaselApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'واصل | Wasel',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF087E8B)),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF6F8FA),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF35B9C2),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        home: const AuthScreen(),
      );
}
