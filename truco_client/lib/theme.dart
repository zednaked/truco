import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TrucoTheme {
  static const primaryColor = Color(0xFF1B5E20);  // Dark green
  static const secondaryColor = Color(0xFFFFD700);  // Gold
  static const backgroundColor = Color(0xFF0A2F0A);  // Darker green
  static const cardColor = Colors.white;
  static const textColor = Colors.white;

  static ThemeData get theme => ThemeData(
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    textTheme: TextTheme(
      displayLarge: GoogleFonts.pressStart2p(
        color: textColor,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      displayMedium: GoogleFonts.pressStart2p(
        color: textColor,
        fontSize: 20,
      ),
      bodyLarge: GoogleFonts.roboto(
        color: textColor,
        fontSize: 18,
      ),
      bodyMedium: GoogleFonts.roboto(
        color: textColor,
        fontSize: 16,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        textStyle: GoogleFonts.pressStart2p(fontSize: 16),
      ),
    ),
    cardTheme: CardTheme(
      color: cardColor,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: secondaryColor, width: 2),
      ),
    ),
  );
}

class GameStyles {
  static BoxDecoration cardTableDecoration = BoxDecoration(
    color: TrucoTheme.primaryColor,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: TrucoTheme.secondaryColor, width: 3),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),
        blurRadius: 15,
        spreadRadius: 5,
      ),
    ],
  );

  static BoxDecoration playedCardDecoration = BoxDecoration(
    color: TrucoTheme.cardColor,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: TrucoTheme.secondaryColor, width: 2),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 10,
        offset: const Offset(0, 5),
      ),
    ],
  );
}
