import 'package:flutter/material.dart';

class AppColors {
  static const cyan = Color(0xFF55C2E8);
  static const cyanDark = Color(0xFF2588A8);

  static const darkBg = Color(0xFF0D1117);
  static const darkSurface = Color(0xFF121820);
  static const darkCard = Color(0xFF171E27);
  static const darkCard2 = Color(0xFF1C2530);

  static const lightBg = Color(0xFFF4F7F9);
  static const lightSurface = Color(0xFFEDF2F5);
  static const lightCard = Color(0xFFFFFFFF);

  static const green = Color(0xFF55C993);
  static const orange = Color(0xFFE9A45F);
  static const red = Color(0xFFE56B72);
  static const purple = Color(0xFF9A8BD8);
  static const blue = Color(0xFF6D9EEB);

  static const textDark = Color(0xFFFFFFFF);
  static const textDarkSub = Color(0xFF8E9AA8);

  static const textLight = Color(0xFF1A1A2E);
  static const textLightSub = Color(0xFF66717E);
}

class AppTheme {
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final c = AppC(dark);
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.cyan,
      brightness: brightness,
      primary: AppColors.cyan,
      surface: c.card,
      error: AppColors.red,
    );
    final border = c.sub.withValues(alpha: dark ? 0.16 : 0.18);
    final radius = BorderRadius.circular(10);

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: c.bg,
      colorScheme: scheme,
      splashColor: AppColors.cyan.withValues(alpha: 0.08),
      highlightColor: AppColors.cyan.withValues(alpha: 0.04),
      dividerColor: border,
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: c.txt),
        actionsIconTheme: IconThemeData(color: c.txt),
        titleTextStyle: TextStyle(
          color: c.txt,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: border),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: radius),
        titleTextStyle: TextStyle(
          color: c.txt,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(color: c.sub, fontSize: 13),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.card,
        modalBackgroundColor: c.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.sub.withValues(alpha: 0.35),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.card,
        surfaceTintColor: Colors.transparent,
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: border),
        ),
        textStyle: TextStyle(color: c.txt, fontSize: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.card,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        hintStyle: TextStyle(color: c.sub, fontSize: 12),
        labelStyle: TextStyle(color: c.sub, fontSize: 12),
        prefixIconColor: c.sub,
        suffixIconColor: c.sub,
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.cyan, width: 1.3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppColors.red, width: 1.3),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.cyan,
          foregroundColor: AppColors.darkBg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cyan,
          foregroundColor: AppColors.darkBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.cyan,
          side: BorderSide(color: AppColors.cyan.withValues(alpha: 0.35)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.cyan,
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.cyan,
        foregroundColor: AppColors.darkBg,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.sub,
        textColor: c.txt,
        dense: true,
        minTileHeight: 42,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: AppColors.cyan,
        collapsedIconColor: c.sub,
        textColor: c.txt,
        collapsedTextColor: c.txt,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.card,
        selectedColor: AppColors.cyan.withValues(alpha: 0.14),
        disabledColor: c.sub.withValues(alpha: 0.08),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        labelStyle: TextStyle(color: c.txt, fontSize: 11),
        secondaryLabelStyle: const TextStyle(color: AppColors.cyan),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.card2,
        contentTextStyle: TextStyle(color: c.txt, fontSize: 12),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.cyan,
        linearTrackColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? AppColors.cyan : c.sub,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.cyan.withValues(alpha: 0.35)
              : c.sub.withValues(alpha: 0.18),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.cyan
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.darkBg),
        side: BorderSide(color: c.sub),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? AppColors.cyan : c.sub,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: CupertinoPageTransitionsBuilder()},
      ),
    );
  }
}

class AppC {
  final bool dark;
  const AppC(this.dark);

  Color get bg => dark ? AppColors.darkBg : AppColors.lightBg;
  Color get surface => dark ? AppColors.darkSurface : AppColors.lightSurface;
  Color get card => dark ? AppColors.darkCard : AppColors.lightCard;
  Color get card2 => dark ? AppColors.darkCard2 : AppColors.lightSurface;
  Color get txt => dark ? AppColors.textDark : AppColors.textLight;
  Color get sub => dark ? AppColors.textDarkSub : AppColors.textLightSub;
  Color get border => sub.withValues(alpha: dark ? 0.16 : 0.18);
}
