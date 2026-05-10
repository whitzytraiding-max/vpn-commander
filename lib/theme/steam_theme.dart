import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

ThemeData buildSteamTheme() {
  final base = ThemeData.dark();
  return base.copyWith(
    scaffoldBackgroundColor: kBgBlack,
    colorScheme: const ColorScheme.dark(
      primary: kBrass,
      secondary: kBrassLight,
      surface: kBgMed,
      error: kRedOn,
      onPrimary: kBgDark,
      onSecondary: kBgDark,
      onSurface: kParchment,
      onError: kParchment,
    ),
    textTheme: GoogleFonts.cinzelTextTheme(base.textTheme).copyWith(
      bodyMedium: GoogleFonts.sourceCodePro(color: kParchment, fontSize: 14),
      bodySmall:  GoogleFonts.sourceCodePro(color: kParchDim, fontSize: 12),
      labelSmall: GoogleFonts.cinzel(color: kBrassLight, fontSize: 10, letterSpacing: 2),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: kBgDark,
      selectedIconTheme: IconThemeData(color: kBrassLight, size: 24),
      unselectedIconTheme: IconThemeData(color: kParchDim, size: 22),
      selectedLabelTextStyle: TextStyle(color: kBrassLight, fontSize: 10),
      unselectedLabelTextStyle: TextStyle(color: kParchDim, fontSize: 10),
      indicatorColor: Color(0xFF3A2810),
    ),
    dividerColor: kBorder,
    cardColor: kBgMed,
    appBarTheme: AppBarTheme(
      backgroundColor: kBgDark,
      foregroundColor: kBrassLight,
      titleTextStyle: GoogleFonts.cinzel(
        color: kBrassLight,
        fontSize: 18,
        letterSpacing: 3,
      ),
      elevation: 0,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: kBgLight,
      contentTextStyle: TextStyle(color: kParchment),
    ),
  );
}
