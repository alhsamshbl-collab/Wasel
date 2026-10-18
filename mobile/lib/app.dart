import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';

const waselTeal = Color(0xFF25B8C2);
const waselInk = Color(0xFF0D171A);

class WaselApp extends StatelessWidget {
  const WaselApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'واصل | Wasel',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: waselTeal, brightness: Brightness.light),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF5F8F9),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF5F8F9),
            foregroundColor: waselInk,
            centerTitle: false,
            elevation: 0,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE1E9EB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: waselTeal, width: 1.6)),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          ),
          cardTheme: CardThemeData(color: Colors.white, elevation: 0, margin: const EdgeInsets.symmetric(vertical: 5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFEAF0F1)))),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: waselTeal, brightness: Brightness.dark),
          useMaterial3: true,
          scaffoldBackgroundColor: waselInk,
          appBarTheme: const AppBarTheme(backgroundColor: waselInk, foregroundColor: Colors.white, elevation: 0),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
          filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))),
        ),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        home: const AuthScreen(),
      );
}
