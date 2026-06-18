import 'package:flutter/material.dart';
import 'pages/login_page.dart';

Future<void> main() async {
  runApp(const MyApp());
}

const _adminLtePrimary = Color(0xFF3C8DBC);
const _adminLteLight = Color(0xFFECF0F5);
const _adminLteSurface = Color(0xFFFFFFFF);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BOC App',
      theme: ThemeData(
        useMaterial3: false,
        brightness: Brightness.light,
        scaffoldBackgroundColor: _adminLteLight,
        colorScheme: const ColorScheme.light(
          primary: _adminLtePrimary,
          onPrimary: Colors.white,
          secondary: Color(0xFF00A65A),
          onSecondary: Colors.white,
          background: _adminLteLight,
          onBackground: Color(0xFF222D32),
          surface: _adminLteSurface,
          onSurface: Color(0xFF444444),
          error: Colors.redAccent,
          onError: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _adminLteSurface,
          foregroundColor: Color(0xFF222D32),
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF444444)),
          titleTextStyle: TextStyle(
            color: Color(0xFF222D32),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          color: _adminLteSurface,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF7F7F7),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFFD2D6DE)),
            borderRadius: BorderRadius.circular(4),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFFD2D6DE)),
            borderRadius: BorderRadius.circular(4),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: _adminLtePrimary),
            borderRadius: BorderRadius.circular(4),
          ),
          labelStyle: const TextStyle(color: Color(0xFF666666)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _adminLtePrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: _adminLtePrimary),
        ),
        dividerColor: const Color(0xFFD2D6DE),
        dialogTheme: DialogThemeData(
          backgroundColor: _adminLteSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      home: const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
