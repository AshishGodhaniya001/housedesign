import 'package:flutter/material.dart';
import 'screens/input_screen.dart';
import 'screens/result_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const royalNavy = Color(0xFF16202C);
    const royalGold = Color(0xFFC89E52);
    const ivory = Color(0xFFF7F1E3);
    const mist = Color(0xFFECE3D0);

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: royalNavy,
        onPrimary: Colors.white,
        secondary: royalGold,
        onSecondary: Color(0xFF1D160C),
        error: Color(0xFFB42318),
        onError: Colors.white,
        surface: ivory,
        onSurface: Color(0xFF1E2A38),
      ),
      scaffoldBackgroundColor: mist,
      fontFamily: 'Georgia',
      appBarTheme: const AppBarTheme(
        backgroundColor: ivory,
        foregroundColor: Color(0xFF152031),
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Color(0xFF152031),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.86),
        elevation: 8,
        shadowColor: const Color(0xFF6A5730).withValues(alpha: 0.18),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFD9C7A4), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: royalNavy,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: royalGold, width: 1.2),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF223044),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: royalGold, width: 1.2),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: royalNavy,
          side: const BorderSide(color: royalGold, width: 1.2),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: royalNavy,
        foregroundColor: Colors.white,
        shape: StadiumBorder(side: BorderSide(color: royalGold, width: 1.2)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFCF6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD6C1A0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: royalNavy, width: 1.4),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorColor: royalGold,
        labelColor: royalNavy,
        unselectedLabelColor: Color(0xFF5B6672),
        labelStyle: TextStyle(fontWeight: FontWeight.w700),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFFFFFBF4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFDDC8A8)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFFFFFBF4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFDDC8A8)),
        ),
      ),
    );

    const deepCharcoal = Color(0xFF0F141B);
    const darkSurface = Color(0xFF151C25);
    const darkCard = Color(0xFF1A2430);

    final darkBase = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: royalGold,
        onPrimary: Color(0xFF1B1407),
        secondary: Color(0xFF7EA3D1),
        onSecondary: Color(0xFF08111E),
        error: Color(0xFFFF7B7B),
        onError: Color(0xFF2A0000),
        surface: darkSurface,
        onSurface: Color(0xFFEFE7D8),
      ),
      scaffoldBackgroundColor: deepCharcoal,
      fontFamily: 'Georgia',
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF111821),
        foregroundColor: Color(0xFFF2E6CF),
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Color(0xFFF2E6CF),
        ),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.32),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF6A5230), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF243446),
          foregroundColor: const Color(0xFFF8E8C9),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: royalGold, width: 1.2),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF2B3F56),
          foregroundColor: const Color(0xFFF6E9D3),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: royalGold, width: 1.2),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFF5DFB5),
          side: const BorderSide(color: royalGold, width: 1.2),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF233245),
        foregroundColor: Color(0xFFF8E8C9),
        shape: StadiumBorder(side: BorderSide(color: royalGold, width: 1.2)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF111923),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF5A4B34)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: royalGold, width: 1.4),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorColor: royalGold,
        labelColor: Color(0xFFF2DEB9),
        unselectedLabelColor: Color(0xFFA8B0BA),
        labelStyle: TextStyle(fontWeight: FontWeight.w700),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF665236)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF665236)),
        ),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '2D Floor Planner',
      theme: base,
      darkTheme: darkBase,
      themeMode: ThemeMode.dark,
      routes: {
        '/': (_) => const InputScreen(),
        '/result': (_) => const ResultScreen(),
      },
    );
  }
}
