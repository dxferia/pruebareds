import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const primary = Color(0xFF007A33);
  static const alert = Color(0xFFE20613);
  static const link = Color(0xFF0085CA);
  static const darkBlue = Color(0xFF005B84);
  static const background = Color(0xFFF8F9FA);
  static const surface = Colors.white;
  static const text = Color(0xFF212529);
  static const textSecondary = Color(0xFF5F6B72);
  static const muted = Color(0xFF7A858B);
  static const border = Color(0xFFDDE3E7);
  static const pendingBg = Color(0xFFFFF3CD);
  static const pendingFg = Color(0xFF664D03);
  static const approvedBg = Color(0xFFD1E7DD);
  static const approvedFg = Color(0xFF0F5132);
  static const rejectedBg = Color(0xFFF8D7DA);
  static const rejectedFg = Color(0xFF842029);
  static const suspendedBg = Color(0xFFE2E3E5);
  static const suspendedFg = Color(0xFF41464B);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.link,
      error: AppColors.alert,
      surface: AppColors.surface,
    ),
  );

  return base.copyWith(
    textTheme: GoogleFonts.robotoTextTheme(base.textTheme).copyWith(
      headlineLarge: GoogleFonts.montserrat(
        fontWeight: FontWeight.w700,
        fontSize: 28,
        color: AppColors.text,
      ),
      headlineMedium: GoogleFonts.montserrat(
        fontWeight: FontWeight.w700,
        fontSize: 24,
        color: AppColors.text,
      ),
      titleLarge: GoogleFonts.montserrat(
        fontWeight: FontWeight.w700,
        fontSize: 20,
        color: AppColors.text,
      ),
      titleMedium: GoogleFonts.montserrat(
        fontWeight: FontWeight.w700,
        fontSize: 16,
        color: AppColors.text,
      ),
      titleSmall: GoogleFonts.montserrat(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: AppColors.text,
      ),
      bodyLarge: GoogleFonts.roboto(fontSize: 16, color: AppColors.text),
      bodyMedium: GoogleFonts.roboto(fontSize: 14, color: AppColors.text),
      bodySmall: GoogleFonts.roboto(fontSize: 12.5, color: AppColors.textSecondary),
      labelLarge: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    appBarTheme: const AppBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: AppColors.surface,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    ),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}
