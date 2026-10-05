import 'package:flutter/material.dart';

/// RIZO brand: purple and orange accents on a light neutral base (never a full purple screen).
class Brand {
  static const purple = Color(0xFF7B00E0);
  static const purpleDark = Color(0xFF6500BD);
  static const purpleTint = Color(0xFFF5EBFD);
  static const orange = Color(0xFFF7941E);
  static const orangeTint = Color(0xFFFFF4E5);
  static const orangeText = Color(0xFFC56A00);
  static const ink = Color(0xFF1E293B);
  static const background = Color(0xFFF5F7FA);
  static const border = Color(0xFFE5E7EB);
  static const green = Color(0xFF047857);
  static const greenTint = Color(0xFFECFDF5);
  static const red = Color(0xFFB91C1C);
  static const redTint = Color(0xFFFEF2F2);
  static const amberTint = Color(0xFFFFFBEB);
  static const amberText = Color(0xFF92400E);
}

bool isTablet(BuildContext context) => MediaQuery.sizeOf(context).shortestSide >= 600;
bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= 720;

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: Brand.purple, primary: Brand.purple, secondary: Brand.orange, surface: Colors.white);
  final border = OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD1D5DB)));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Brand.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Brand.ink,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: TextStyle(color: Brand.ink, fontSize: 18, fontWeight: FontWeight.w800),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Brand.border)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: const BorderSide(color: Brand.purple, width: 2)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: Brand.purple,
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        foregroundColor: Brand.ink,
        side: const BorderSide(color: Color(0xFFD1D5DB)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Brand.purple, textStyle: const TextStyle(fontWeight: FontWeight.w700))),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide.none,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Brand.purpleTint,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    ),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    dividerColor: Brand.border,
  );
}
