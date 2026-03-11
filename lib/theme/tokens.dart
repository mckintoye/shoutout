import 'package:flutter/material.dart';

class AppTokens {


/*
  // Palette
  static const Color bg = Color(0xFFF7F7FB);

  // Section background tints (light, subtle)
  static const Color tintBlue = Color(0xFFEAF2FF);
  static const Color tintLav = Color(0xFFF3F4FF);

  static const Color card = Colors.white;
  static const Color ink = Color(0xFF0D0D0D);
  static const Color subInk = Color(0xFF4A5568);
  static const Color stroke = Color(0x11000000);

  */

  static const Color textPrimary = ink;
  static const Color textSecondary = subInk; // muted
  static const Color textDisabled = Color(0xFF98A2B3);

  static const Color mutedSurface = Color(0xFFF2F4F7);
  // Colors (CashLens)
  static const Color ink = Color(0xFF0B0F14);
  static const Color subInk = Color(0xFF667085); // muted
  static const Color bg = Color(0xFFF6F7F9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color stroke = Color(0xFFE6E8EC);

  // Brand accent (CashLens calm blue)
  static const Color accent = Color(0xFF1570EF);
  static const Color accentSoft = Color(0xFFEAF2FF);

  static const Color muted = subInk;

  // Radius (CashLens style)
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r20 = 20;
  static const double r24 = 24; // keep name for compatibility, align feel

  // Spacing
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s40 = 40;

  // Typography (CashLens feel) — keep existing names to avoid breaking calls
  static const TextStyle h1 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.2,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.1,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    height: 1.25,
    letterSpacing: -0.0,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  static const TextStyle small = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  // Added (non-breaking): CashLens-specific utility styles
  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.6,
    height: 1.2,
  );

  static const TextStyle helper = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  static const TextStyle amount = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w900,
    height: 1.1,
  );

  // Status (keep)
  static const Color positive = Color(0xFF1570EF);
  static const Color negative = Color(0xFFD92D20);

  // Legacy (keep)
  static const r18 = 18.0;
  static const r22 = 22.0;

  static const Color sectionBlue = Color(0xFFEAF2FF);      // soft sky blue
  static const Color sectionLavender = Color(0xFFFAF8FF);  // soft lavender



  // =========================
  // COLORS
  // =========================

  /// Light blue section background (My Events)
  static const Color tintBlue = Color(0xFFEAF2FF);

  /// Light lavender section background (Joined Events)
  static const Color tintLav = Color(0xFFF3F4FF);


  // =========================
  // TYPOGRAPHY
  // =========================

  /// Section Title (e.g., My Events / Joined Events)

  /// Event title inside card
  static const TextStyle title = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w800,
  height: 1.2,
  );

  /// Subtitle / helper text
  static   TextStyle sub = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: subInk.withOpacity(0.75),
  height: 1.3,
  );

  /// Badge count text
  static const TextStyle badge = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w800,
  );


  // Layout
  static const EdgeInsets pagePad = EdgeInsets.fromLTRB(16, 12, 16, 16);
  static const double radius = 24;


  // Typography
  static const TextStyle subhead = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: subInk,
  height: 1.2,
  );

  static const TextStyle caption = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: subInk,
  height: 1.2,
  );




  }


