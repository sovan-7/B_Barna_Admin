import 'package:flutter/material.dart';

/// Shared design tokens for the app shell (header, sidebar, page canvas).
///
/// The screens in this codebase each pick their own greys — `Colors.grey`
/// at `.2`, `.4`, `.5` — so no two panels sit on the same background and
/// nothing lines up. Shell chrome goes through this file instead.
///
/// Accents stay on [AppColorsInApp] so the app keeps its identity; what is
/// defined here is the neutral ramp everything else is drawn on.
class AppTokens {
  const AppTokens._();

  // ---- Spacing (4pt scale) --------------------------------------------
  static const double gapXs = 4;
  static const double gapSm = 8;
  static const double gapMd = 14;
  static const double gapLg = 20;
  static const double gapXl = 28;

  // ---- Radii ----------------------------------------------------------
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusPill = 999;

  // ---- Neutral ramp ---------------------------------------------------
  static const Color canvas = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF2F4F7);
  static const Color hairline = Color(0xFFE4E8EE);
  static const Color ink = Color(0xFF15181D);
  static const Color inkMuted = Color(0xFF667085);
  static const Color inkFaint = Color(0xFF98A2B3);

  // ---- Shell metrics --------------------------------------------------
  /// Width of the navigation rail when it shows labels.
  static const double railWidth = 260;

  /// Width when it is reduced to icons.
  static const double railCollapsedWidth = 72;

  /// Below this the rail drops to icons on its own, so the cramped
  /// `Expanded(child: ExtraSideBar(...))` panels on the add/edit screens
  /// show whole icons instead of clipped words.
  static const double railAutoCollapseWidth = 180;

  /// The width at which the shell switches from a rail to a drawer. Shared
  /// by [Sidebar], [AppHeader] and every add/edit screen.
  static const double compactBreakpoint = 900;

  static const double headerHeight = 56;

  static const Color danger = Color(0xFFD92D20);

  /// A tight contact shadow plus a wide soft one, rather than one big blur
  /// — cards read as resting on the page instead of floating over it.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0F101828), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A101828), blurRadius: 14, offset: Offset(0, 6)),
  ];

  // ---- Page type ------------------------------------------------------
  static const TextStyle pageTitle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: ink);
  static const TextStyle pageSubtitle =
      TextStyle(fontSize: 13, height: 1.35, color: inkMuted);
  static const TextStyle sectionTitle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: inkFaint);
  static const TextStyle body =
      TextStyle(fontSize: 13, height: 1.45, color: inkMuted);
  static const TextStyle errorText =
      TextStyle(fontSize: 11.5, height: 1.3, color: danger);

  /// Label above a form field ("Course name", "Display priority", …).
  static const TextStyle fieldLabel = TextStyle(
      fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF344054));

  // ---- Nav type -------------------------------------------------------
  /// Idle navigation items are near-black, not grey. A sidebar is a list
  /// of destinations, all of them available — greying them makes every row
  /// read as disabled, and there is nothing brighter beside them for the
  /// grey to be a contrast *against*.
  static const TextStyle navItem =
      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: ink);
  static const TextStyle navItemSelected =
      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600);
}
