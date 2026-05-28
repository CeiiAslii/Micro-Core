import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const cyan = Color(0xFF00D4FF);
  static const cyanDark = Color(0xFF0099BB);

  // Dark theme
  static const darkBg = Color(0xFF0A0A14);
  static const darkSurface = Color(0xFF12121F);
  static const darkCard = Color(0xFF1A1A2E);
  static const darkCard2 = Color(0xFF1F1F35);

  // Light theme
  static const lightBg = Color(0xFFF0F4FF);
  static const lightSurface = Color(0xFFE8EEFF);
  static const lightCard = Color(0xFFFFFFFF);

  // Accent
  static const green = Color(0xFF00E676);
  static const orange = Color(0xFFFF9800);
  static const red = Color(0xFFFF5252);
  static const purple = Color(0xFF7C4DFF);
  static const blue = Color(0xFF2979FF);

  // Text dark
  static const textDark = Color(0xFFFFFFFF);
  static const textDarkSub = Color(0xFF8888AA);

  // Text light
  static const textLight = Color(0xFF1A1A2E);
  static const textLightSub = Color(0xFF666688);
}

class AppTheme {
  static ThemeData dark() => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.cyan,
      surface: AppColors.darkSurface,
    ),
    useMaterial3: true,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkSurface,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.textDark),
      titleTextStyle: TextStyle(
        color: AppColors.textDark,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: AppColors.darkSurface),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: CupertinoPageTransitionsBuilder()},
    ),
  );

  static ThemeData light() => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.cyan,
      surface: AppColors.lightSurface,
    ),
    useMaterial3: true,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightCard,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.textLight),
      titleTextStyle: TextStyle(
        color: AppColors.textLight,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: AppColors.lightCard),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: CupertinoPageTransitionsBuilder()},
    ),
  );
}

// Helper class untuk akses warna berdasarkan mode
class AppC {
  final bool dark;
  const AppC(this.dark);

  Color get bg => dark ? AppColors.darkBg : AppColors.lightBg;
  Color get surface => dark ? AppColors.darkSurface : AppColors.lightSurface;
  Color get card => dark ? AppColors.darkCard : AppColors.lightCard;
  Color get card2 => dark ? AppColors.darkCard2 : AppColors.lightSurface;
  Color get txt => dark ? AppColors.textDark : AppColors.textLight;
  Color get sub => dark ? AppColors.textDarkSub : AppColors.textLightSub;
}
