import 'package:flutter/material.dart';

/// Shared design tokens: spacing, radii, the neutral colour ramp, shadows
/// and text styles used by the shell, lists, cards and forms, so every
/// screen sits on the same greys and lines up.
///
/// Brand accents stay in [AppColorsInApp]; this file is the neutral ramp.
class AppTokens {
  const AppTokens._();

  // ---- Spacing (4pt scale) --------------------------------------------
  /// Tiny gap (icon ↔ text).
  static const double gapXs = 4;

  /// Small gap between related items.
  static const double gapSm = 8;

  /// Default gap between fields and sections.
  static const double gapMd = 14;

  /// Gap between page blocks.
  static const double gapLg = 20;

  /// Extra space at the end of a page.
  static const double gapXl = 28;

  // ---- Radii ----------------------------------------------------------
  /// Corner radius for chips, thumbnails and small buttons.
  static const double radiusSm = 8;

  /// Corner radius for cards, fields and sections.
  static const double radiusMd = 12;

  /// Fully rounded ends (pills, circles).
  static const double radiusPill = 999;

  // ---- Neutral ramp ---------------------------------------------------
  /// Page background behind cards.
  static const Color canvas = Color(0xFFF5F7FA);

  /// Card / field background.
  static const Color surface = Color(0xFFFFFFFF);

  /// Subtle grey fill (placeholders, disabled fields, neutral chips).
  static const Color surfaceMuted = Color(0xFFF2F4F7);

  /// Thin borders and dividers.
  static const Color hairline = Color(0xFFE4E8EE);

  /// Primary text.
  static const Color ink = Color(0xFF15181D);

  /// Secondary text and icons.
  static const Color inkMuted = Color(0xFF667085);

  /// Hints, placeholders and tertiary icons.
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

  /// Height of the top [AppHeader] bar.
  static const double headerHeight = 56;

  /// Errors and destructive actions.
  static const Color danger = Color(0xFFD92D20);

  /// A tight contact shadow plus a wide soft one, rather than one big blur
  /// — cards read as resting on the page instead of floating over it.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0F101828), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A101828), blurRadius: 14, offset: Offset(0, 6)),
  ];

  // ---- Page type ------------------------------------------------------
  /// Page title ("PDFs", "Add a course").
  static const TextStyle pageTitle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: ink);

  /// One-line description under a page title.
  static const TextStyle pageSubtitle =
      TextStyle(fontSize: 13, height: 1.35, color: inkMuted);

  /// Upper-case section heading inside a form card.
  static const TextStyle sectionTitle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: inkFaint);

  /// Body text (descriptions on cards).
  static const TextStyle body =
      TextStyle(fontSize: 13, height: 1.45, color: inkMuted);

  /// Inline validation message under a field.
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

  /// Selected sidebar item.
  static const TextStyle navItemSelected =
      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600);
}
