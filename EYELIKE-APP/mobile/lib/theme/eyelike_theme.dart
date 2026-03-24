import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Synth / optic-lab palette — meant to read as a deliberate test harness, not generic UI.
class EyelikeColors {
  static const voidBlack = Color(0xFF07080D);
  static const panel = Color(0xFF10121A);
  static const cyan = Color(0xFF2EE6D6);
  static const magenta = Color(0xFFFF3DA8);
  static const amber = Color(0xFFFFB547);
  static const dim = Color(0xFF6B7288);
}

ThemeData buildEyelikeTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: EyelikeColors.voidBlack,
    colorScheme: const ColorScheme.dark(
      surface: EyelikeColors.panel,
      primary: EyelikeColors.cyan,
      secondary: EyelikeColors.magenta,
      tertiary: EyelikeColors.amber,
      onSurface: Color(0xFFE8EAFF),
    ),
  );
  return base.copyWith(
    textTheme: GoogleFonts.shareTechMonoTextTheme(base.textTheme).apply(
      bodyColor: const Color(0xFFD5D8E8),
      displayColor: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: EyelikeColors.panel.withValues(alpha: 0.85),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: EyelikeColors.cyan.withValues(alpha: 0.35)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: EyelikeColors.cyan.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: EyelikeColors.cyan, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: EyelikeColors.cyan,
        foregroundColor: EyelikeColors.voidBlack,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: EyelikeColors.magenta,
        side: BorderSide(color: EyelikeColors.magenta.withValues(alpha: 0.6)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

TextStyle titleEyelike(double size) => GoogleFonts.russoOne(
      fontSize: size,
      letterSpacing: 0.5,
      height: 1.05,
    );
