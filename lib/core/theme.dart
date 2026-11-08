import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kPrimary = Color(0xFF0B7F69);
const kAccent = Color(0xFFFF7A59);

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: kPrimary, brightness: b, secondary: kAccent);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
  return base.copyWith(
    scaffoldBackgroundColor: dark ? const Color(0xFF0E1513) : const Color(0xFFF6FAF9),
    textTheme: GoogleFonts.cairoTextTheme(base.textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w700, color: scheme.onSurface),
    ),
  );
}

class StatusStyle {
  final Color fg, bg;
  const StatusStyle(this.fg, this.bg);
}

/// ألوان حالات الرد (نص + خلفية ناعمة). غير متوفر بالرمادي مش الأحمر عشان ما يقلقش.
StatusStyle statusStyle(String status, bool dark) {
  switch (status) {
    case 'Available':
    case 'Delivered':
      return dark ? const StatusStyle(Color(0xFF4ADE9A), Color(0xFF10301F)) : const StatusStyle(Color(0xFF067647), Color(0xFFE7F8EF));
    case 'Partial':
      return dark ? const StatusStyle(Color(0xFFF5C451), Color(0xFF3A2D0E)) : const StatusStyle(Color(0xFF93600A), Color(0xFFFEF3DC));
    case 'Unavailable':
    case 'Expired':
      return dark ? const StatusStyle(Color(0xFFB6C0CC), Color(0xFF252C33)) : const StatusStyle(Color(0xFF475467), Color(0xFFEEF0F3));
    default: // Pending
      return dark ? const StatusStyle(Color(0xFF8DB0FF), Color(0xFF1A2744)) : const StatusStyle(Color(0xFF2A55B8), Color(0xFFE8EFFD));
  }
}

/// لون الدبوس في الرادار
Color pinColor(String status) {
  switch (status) {
    case 'Available':
    case 'Delivered':
      return const Color(0xFF12B76A);
    case 'Partial':
      return const Color(0xFFF5A524);
    case 'Unavailable':
    case 'Expired':
      return const Color(0xFF98A2B3);
    default:
      return const Color(0xFF5B8DEF);
  }
}
