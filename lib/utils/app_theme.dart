import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand palette, shared by the splash screen and both themes.
class AppColors {
  static const ink = Color(0xFF061528); // dark background, text on light
  static const navy = Color(0xFF0C2D4D); // top of gradients
  static const surface = Color(0xFF0E2640); // dark cards, inputs, sheets
  static const mint = Color(0xFF2EE6A6); // primary accent (dark mode)
  static const sky = Color(0xFF4CC9F0); // secondary accent
  static const amber = Color(0xFFFFC857); // warnings, highlights
  static const coral = Color(0xFFFF6B6B); // errors, expenses
  static const mist = Color(0xFFF2F7FB); // light background, text on dark
  static const slate = Color(0xFF9DB4C8); // secondary text on dark

  // Light-mode versions: deeper tones so they stay readable on white
  static const mintDeep = Color(0xFF0E9F74);
  static const skyDeep = Color(0xFF1B8FB8);
  static const amberDeep = Color(0xFFB77900);
  static const coralDeep = Color(0xFFD64545);
  static const inkSoft = Color(0xFF4A6178); // secondary text on light
}

/// Everything that differs between light and dark lives here.
class _Palette {
  const _Palette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.text,
    required this.textSecondary,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.tertiary,
    required this.error,
    required this.border,
    required this.overlay,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color text;
  final Color textSecondary;
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color tertiary;
  final Color error;
  final Color border;
  final SystemUiOverlayStyle overlay;
}

final _darkPalette = _Palette(
  brightness: Brightness.dark,
  background: AppColors.ink,
  surface: AppColors.surface,
  text: AppColors.mist,
  textSecondary: AppColors.slate,
  primary: AppColors.mint,
  onPrimary: AppColors.ink,
  secondary: AppColors.sky,
  tertiary: AppColors.amber,
  error: AppColors.coral,
  border: Colors.white.withValues(alpha: 0.08),
  overlay: SystemUiOverlayStyle.light,
);

final _lightPalette = _Palette(
  brightness: Brightness.light,
  background: AppColors.mist,
  surface: Colors.white,
  text: AppColors.ink,
  textSecondary: AppColors.inkSoft,
  primary: AppColors.mintDeep,
  onPrimary: Colors.white,
  secondary: AppColors.skyDeep,
  tertiary: AppColors.amberDeep,
  error: AppColors.coralDeep,
  border: AppColors.ink.withValues(alpha: 0.10),
  overlay: SystemUiOverlayStyle.dark,
);

class AppTheme {
  static ThemeData get dark => _build(_darkPalette);
  static ThemeData get light => _build(_lightPalette);

  /// Body text in DM Sans, headings in Sora (same pairing as the splash)
  static TextTheme _textTheme(_Palette p) {
    final base = ThemeData(brightness: p.brightness, useMaterial3: true);
    final t = GoogleFonts.dmSansTextTheme(base.textTheme)
        .copyWith(
      headlineLarge: GoogleFonts.sora(
          fontSize: 30, fontWeight: FontWeight.w600),
      headlineMedium: GoogleFonts.sora(
          fontSize: 24, fontWeight: FontWeight.w600),
      titleLarge: GoogleFonts.sora(
          fontSize: 20, fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.sora(
          fontSize: 16, fontWeight: FontWeight.w600),
    )
        .apply(bodyColor: p.text, displayColor: p.text);

    // Small captions use the softer text colour
    return t.copyWith(
      bodySmall: t.bodySmall?.copyWith(color: p.textSecondary),
    );
  }

  static ThemeData _build(_Palette p) {
    final base = ThemeData(brightness: p.brightness, useMaterial3: true);
    final textTheme = _textTheme(p);

    final colorScheme = ColorScheme(
      brightness: p.brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.secondary,
      onSecondary: p.brightness == Brightness.dark
          ? AppColors.ink
          : Colors.white,
      tertiary: p.tertiary,
      error: p.error,
      onError: Colors.white,
      surface: p.background,
      onSurface: p.text,
      onSurfaceVariant: p.textSecondary,
      surfaceContainer: p.surface,
      surfaceContainerHighest: p.surface,
      outline: p.textSecondary,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.background,
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: p.overlay,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: p.text),
      ),

      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.border),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.dmSans(
              fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.dmSans(
              fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.primary),
      ),

      iconTheme: IconThemeData(color: p.text),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        labelStyle: TextStyle(color: p.textSecondary),
        hintStyle: TextStyle(color: p.textSecondary),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.error),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor:
        p.brightness == Brightness.dark ? AppColors.surface : AppColors.ink,
        contentTextStyle: GoogleFonts.dmSans(color: AppColors.mist),
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      dividerTheme: DividerThemeData(color: p.border, thickness: 1),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.primary),
    );
  }
}

/// Holds the current mode. Change it from anywhere with [toggleTheme].
final ValueNotifier<ThemeMode> themeModeNotifier =
ValueNotifier<ThemeMode>(ThemeMode.dark);

void toggleTheme() {
  themeModeNotifier.value = themeModeNotifier.value == ThemeMode.dark
      ? ThemeMode.light
      : ThemeMode.dark;
}