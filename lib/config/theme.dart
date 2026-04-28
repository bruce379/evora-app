import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Evora brand colors - to be finalised with design review
class EvoraColors {
  // Primary - to confirm from design
  static const Color primary = Color(0xFF0A0A0A);
  static const Color primaryAccent = Color(0xFF00E5C8); // teal/mint - placeholder
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF141414);
  static const Color surfaceElevated = Color(0xFF1E1E1E);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color textMuted = Color(0xFF5C5C5C);

  // Status
  static const Color success = Color(0xFF00C896);
  static const Color warning = Color(0xFFFFB020);
  static const Color error = Color(0xFFFF4D4D);

  // Device status
  static const Color deviceConnected = Color(0xFF00C896);
  static const Color deviceDisconnected = Color(0xFF5C5C5C);

  // Border
  static const Color border = Color(0xFF2A2A2A);
  static const Color borderLight = Color(0xFF3A3A3A);
}

class EvoraTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: EvoraColors.background,
    colorScheme: const ColorScheme.dark(
      primary: EvoraColors.primaryAccent,
      surface: EvoraColors.surface,
      onSurface: EvoraColors.textPrimary,
      error: EvoraColors.error,
    ),
    textTheme: GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    ).copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        color: EvoraColors.textPrimary,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: EvoraColors.textPrimary,
        letterSpacing: -0.3,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: EvoraColors.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: EvoraColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: EvoraColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: EvoraColors.textSecondary,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: EvoraColors.textPrimary,
        letterSpacing: 0.5,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: EvoraColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: EvoraColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: EvoraColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: EvoraColors.primaryAccent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: EvoraColors.error),
      ),
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        color: EvoraColors.textMuted,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: EvoraColors.primaryAccent,
        foregroundColor: EvoraColors.primary,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
        elevation: 0,
      ),
    ),
    cardTheme: CardTheme(
      color: EvoraColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: EvoraColors.border),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: EvoraColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: EvoraColors.textPrimary),
      titleTextStyle: TextStyle(
        color: EvoraColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
