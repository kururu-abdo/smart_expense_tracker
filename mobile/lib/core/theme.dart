import 'package:flutter/material.dart';

const ink = Color(0xFF123F37);
const emerald = Color(0xFF176B54);
const lime = Color(0xFFD9F5A4);
const cream = Color(0xFFF5F5EF);

ThemeData appTheme(bool dark, bool arabic) {
  final scheme = ColorScheme.fromSeed(
    seedColor: emerald,
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: dark ? const Color(0xFF91D8B5) : emerald,
    surface: dark ? const Color(0xFF172721) : Colors.white,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: arabic ? 'NotoArabic' : 'Manrope',
    fontFamilyFallback: arabic ? ['Manrope'] : ['NotoArabic'],
  );
  return base.copyWith(
    scaffoldBackgroundColor: dark ? const Color(0xFF0E1B17) : cream,
    textTheme: base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 1.18,
        letterSpacing: arabic ? 0 : -1.3,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.25,
        letterSpacing: arabic ? 0 : -0.8,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.5),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: TextStyle(
          fontFamily: arabic ? 'NotoArabic' : 'Manrope',
          fontFamilyFallback: arabic ? ['Manrope'] : ['NotoArabic'],
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF20362D) : const Color(0xFFEEF0E8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      elevation: 0,
      indicatorColor: dark ? emerald : lime,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontFamily: arabic ? 'NotoArabic' : 'Manrope',
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

Color categoryColor(String category) => switch (category) {
  'food' => const Color(0xFFEAB27B),
  'groceries' => const Color(0xFF9AC69C),
  'transport' => const Color(0xFF95BAD3),
  'shopping' => const Color(0xFFC7B1DE),
  'bills' => const Color(0xFF6BA38B),
  'health' => const Color(0xFFE7A4AB),
  'entertainment' => const Color(0xFFDAC56F),
  'salary' => const Color(0xFF9EDFC2),
  _ => const Color(0xFFBCC5BE),
};

IconData categoryIcon(String category) => switch (category) {
  'food' => Icons.local_cafe_outlined,
  'groceries' => Icons.shopping_basket_outlined,
  'transport' => Icons.directions_car_outlined,
  'shopping' => Icons.shopping_bag_outlined,
  'bills' => Icons.home_outlined,
  'health' => Icons.favorite_border,
  'entertainment' => Icons.movie_outlined,
  'salary' => Icons.account_balance_wallet_outlined,
  _ => Icons.category_outlined,
};
