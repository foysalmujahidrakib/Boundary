import 'package:google_fonts/google_fonts.dart';

import '../ui.dart';
import 'app_colors.dart';

/// Typography from the web CSS: DM Sans for body text, Manrope (800) for
/// headings and numbers, Anton for the big scoring buttons.
///
/// Only the `TextStyle`-returning Google Fonts functions are used (never the
/// `xxxTextTheme()` helpers) so the code is identical with the standalone
/// `material_ui` package and the in-SDK Material library.
abstract final class AppText {
  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.white,
    double? height,
    double? letterSpacing,
  }) => GoogleFonts.dmSans(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  static TextStyle heading({
    double size = 20,
    FontWeight weight = FontWeight.w800,
    Color color = AppColors.white,
    double? height,
    double? letterSpacing,
  }) => GoogleFonts.manrope(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  /// The chunky numerals on the scoring pad (`font: 800 40px Anton`).
  static TextStyle score({double size = 36, Color color = AppColors.onMint}) =>
      GoogleFonts.anton(fontSize: size, color: color);

  /// Small spaced-out caps used for section eyebrows (`.eyebrow`).
  static TextStyle eyebrow({Color color = AppColors.white}) =>
      body(size: 10, weight: FontWeight.w700, color: color, letterSpacing: 1.6);

  /// Muted helper text.
  static TextStyle muted({double size = 12}) =>
      body(size: size, color: AppColors.muted);
}

abstract final class AppTheme {
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppColors.mint,
      onPrimary: AppColors.onMint,
      secondary: AppColors.orange,
      onSecondary: AppColors.white,
      surface: AppColors.surface,
      onSurface: AppColors.white,
      error: Color(0xFFFF6B6B),
      outline: AppColors.line,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.line),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      canvasColor: AppColors.canvas,
      dividerColor: AppColors.line,
      textTheme: TextTheme(
        displayLarge: AppText.heading(
          size: 49,
          letterSpacing: -2.5,
          height: 1.08,
        ),
        headlineMedium: AppText.heading(size: 28),
        headlineSmall: AppText.heading(size: 22),
        titleLarge: AppText.heading(size: 18, weight: FontWeight.w700),
        titleMedium: AppText.heading(size: 15, weight: FontWeight.w700),
        titleSmall: AppText.heading(size: 13, weight: FontWeight.w700),
        bodyLarge: AppText.body(size: 15),
        bodyMedium: AppText.body(size: 13),
        bodySmall: AppText.body(size: 11, color: AppColors.muted),
        labelLarge: AppText.body(size: 13, weight: FontWeight.w700),
        labelSmall: AppText.body(size: 10, weight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.heading(size: 17),
        shape: const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.canvas,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        labelStyle: AppText.body(size: 13, color: AppColors.muted),
        floatingLabelStyle: AppText.body(
          size: 13,
          color: AppColors.mint,
          weight: FontWeight.w700,
        ),
        hintStyle: AppText.body(size: 13, color: AppColors.muted),
        helperStyle: AppText.muted(size: 11),
        errorStyle: AppText.body(size: 11, color: const Color(0xFFFF8A8A)),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.mint, width: 1.4),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.mint,
          foregroundColor: AppColors.onMint,
          disabledBackgroundColor: AppColors.mint.withValues(alpha: 0.35),
          disabledForegroundColor: AppColors.onMint.withValues(alpha: 0.6),
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: AppText.body(size: 13, weight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.white,
          side: const BorderSide(color: AppColors.line),
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: AppText.body(size: 13, weight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.white,
          textStyle: AppText.body(size: 13, weight: FontWeight.w700),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceRaised,
        contentTextStyle: AppText.body(size: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: AppText.heading(size: 18, weight: FontWeight.w700),
        contentTextStyle: AppText.body(size: 13, color: AppColors.muted),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surfaceRaised,
        textStyle: AppText.body(size: 13),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.mint,
      ),
    );
  }
}
