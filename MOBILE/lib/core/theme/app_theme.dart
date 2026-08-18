import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dashcam-optimised dark theme.
///
/// High-contrast status colours (red = recording, green = live,
/// amber = connecting) on a near-black background reduce glare
/// while driving at night.
class AppTheme {
  AppTheme._();

  // ── Palette ──────────────────────────────────────────────
  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF14141F);
  static const Color surfaceVariant = Color(0xFF1E1E2E);
  static const Color primary = Color(0xFF6C63FF);
  static const Color accent = Color(0xFF00E5FF);

  // Status colours
  static const Color liveRed = Color(0xFFFF3B3B);
  static const Color connectingAmber = Color(0xFFFFB300);
  static const Color successGreen = Color(0xFF00E676);
  static const Color reconnectBlue = Color(0xFF448AFF);
  static const Color errorRed = Color(0xFFFF1744);

  static const Color textPrimary = Color(0xFFEEEEEE);
  static const Color textSecondary = Color(0xFF9E9E9E);

  // ── Theme Data ───────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: errorRed,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
