import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Design tokens for the Live Class module.
///
/// The older modules hand-roll `withValues(alpha: .2)` greys and one-off
/// font sizes at every call site, which is why no two screens quite line up.
/// Everything visual here goes through this one file instead: a spacing
/// scale, a neutral ramp, one elevation, and a per-status accent — so the
/// list, the card and the form read as the same product.
class LiveClassTheme {
  const LiveClassTheme._();

  // ---- Spacing scale (4pt) -------------------------------------------
  static const double gapXs = 4;
  static const double gapSm = 8;
  static const double gapMd = 14;
  static const double gapLg = 20;
  static const double gapXl = 28;

  // ---- Radii ----------------------------------------------------------
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusPill = 999;

  /// Cards stop growing at this width; past it the list adds a column
  /// rather than stretching a card to the full width of a 27" monitor.
  static const double cardMaxWidth = 460;
  static const double cardMinWidth = 340;

  // ---- Neutral ramp ---------------------------------------------------
  static const Color canvas = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF7F9FB);
  static const Color hairline = Color(0xFFE4E8EE);
  static const Color ink = Color(0xFF15181D);
  static const Color inkMuted = Color(0xFF667085);
  static const Color inkFaint = Color(0xFF98A2B3);
  static const Color danger = Color(0xFFD92D20);

  /// Two stacked shadows — a tight contact shadow plus a wide soft one — so
  /// cards read as resting on the page rather than floating over it.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0F101828), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A101828), blurRadius: 14, offset: Offset(0, 6)),
  ];

  static const List<BoxShadow> raisedShadow = [
    BoxShadow(color: Color(0x14101828), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x14101828), blurRadius: 24, offset: Offset(0, 12)),
  ];

  // ---- Status accents -------------------------------------------------
  /// Tuned against the app's blue/red/grey so the three states stay
  /// distinguishable at badge size and when reduced to a 3px card stripe.
  static Color accentFor(LiveClassStatus status) {
    switch (status) {
      case LiveClassStatus.upcoming:
        return const Color(0xFF2563EB);
      case LiveClassStatus.live:
        return const Color(0xFFE0393E);
      case LiveClassStatus.past:
        return const Color(0xFF8A94A6);
    }
  }

  static Color tintFor(LiveClassStatus status) =>
      accentFor(status).withValues(alpha: .10);

  static Color borderFor(LiveClassStatus status) =>
      accentFor(status).withValues(alpha: .28);

  static IconData iconFor(LiveClassStatus status) {
    switch (status) {
      case LiveClassStatus.upcoming:
        return Icons.event_outlined;
      case LiveClassStatus.live:
        return Icons.sensors;
      case LiveClassStatus.past:
        return Icons.history;
    }
  }

  /// Theme for `showDatePicker` / `showTimePicker`.
  ///
  /// The stock dialogs arrive in Material's default purple, which reads as
  /// a system dialog dropped onto the page rather than part of it. This
  /// re-skins them with the module's own accent, surfaces and radii.
  static ThemeData pickerTheme(BuildContext context) {
    final ThemeData base = Theme.of(context);
    final Color accent = accentFor(LiveClassStatus.upcoming);

    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        onPrimary: Colors.white,
        surface: surface,
        onSurface: ink,
        surfaceTint: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg)),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: accent,
        headerForegroundColor: Colors.white,
        dividerColor: hairline,
        todayBorder: BorderSide(color: accent, width: 1.2),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg)),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: surface,
        dialBackgroundColor: surfaceMuted,
        hourMinuteColor: surfaceMuted,
        hourMinuteTextColor: ink,
        dayPeriodColor: tintFor(LiveClassStatus.upcoming),
        dayPeriodTextColor: ink,
        dayPeriodBorderSide: const BorderSide(color: hairline),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg)),
        hourMinuteShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
    );
  }

  // ---- Type scale -----------------------------------------------------
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
  static const TextStyle cardTitle = TextStyle(
      fontSize: 15.5,
      fontWeight: FontWeight.w600,
      height: 1.3,
      letterSpacing: -0.1,
      color: ink);
  static const TextStyle body =
      TextStyle(fontSize: 13, height: 1.45, color: inkMuted);
  static const TextStyle meta =
      TextStyle(fontSize: 12.5, height: 1.3, color: inkMuted);
  static const TextStyle metaStrong = TextStyle(
      fontSize: 12.5, height: 1.3, fontWeight: FontWeight.w600, color: ink);
  static const TextStyle fieldLabel = TextStyle(
      fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF344054));
  static const TextStyle errorText =
      TextStyle(fontSize: 11.5, height: 1.3, color: danger);
}

/// Every date/time string the live class module renders, defined once so
/// the card and the form always format dates the same way.
class LiveClassFormat {
  const LiveClassFormat._();

  static final DateFormat date = DateFormat("d MMM yyyy");
  static final DateFormat dateShort = DateFormat("d MMM");
  static final DateFormat time = DateFormat("h:mm a");
  static final DateFormat full = DateFormat("d MMM yyyy, h:mm a");
  static final DateFormat weekday = DateFormat("EEEE");

  /// "12 Mar, 6:00 – 7:30 PM" on one day; both dates spelled out when the
  /// class runs across midnight.
  static String schedule(LiveClassModel liveClass) {
    final DateTime start = liveClass.startDateTime;
    final DateTime end = liveClass.endDateTime;
    final bool sameDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    if (sameDay) {
      return "${date.format(start)} · ${time.format(start)} – ${time.format(end)}";
    }
    return "${full.format(start)} – ${full.format(end)}";
  }

  /// "1h 30m" — shown next to the schedule so the length of a class is
  /// readable without subtracting two timestamps in your head.
  static String duration(DateTime start, DateTime end) {
    final Duration d = end.difference(start);
    if (d.inMinutes <= 0) return "—";
    final int hours = d.inHours;
    final int minutes = d.inMinutes.remainder(60);
    if (hours == 0) return "${minutes}m";
    if (minutes == 0) return "${hours}h";
    return "${hours}h ${minutes}m";
  }

  /// A round length as a chip label: 30m, 45m, 1h, 1h 30m, 2h.
  static String minutes(int value) {
    final int hours = value ~/ 60;
    final int rest = value % 60;
    if (hours == 0) return "${rest}m";
    if (rest == 0) return "${hours}h";
    return "${hours}h ${rest}m";
  }

  /// A [TimeOfDay] in the same 12-hour shape as every other time here.
  /// Formatted off a throwaway date so it does not need a BuildContext.
  static String timeOfDay(TimeOfDay value) =>
      time.format(DateTime(2000, 1, 1, value.hour, value.minute));

  /// The one line that tells an admin whether this class needs them now:
  /// "Starts in 2 days", "Ends in 24 min", "Ended 3 days ago".
  static String relative(LiveClassModel liveClass, {DateTime? now}) {
    final DateTime at = now ?? DateTime.now();
    switch (liveClass.statusAt(at)) {
      case LiveClassStatus.upcoming:
        return "Starts in ${_span(liveClass.startDateTime.difference(at))}";
      case LiveClassStatus.live:
        return "Ends in ${_span(liveClass.endDateTime.difference(at))}";
      case LiveClassStatus.past:
        return "Ended ${_span(at.difference(liveClass.endDateTime))} ago";
    }
  }

  static String _span(Duration d) {
    if (d.inMinutes < 1) return "under a minute";
    if (d.inMinutes < 60) return "${d.inMinutes} min";
    if (d.inHours < 24) {
      final int minutes = d.inMinutes.remainder(60);
      return minutes == 0 ? "${d.inHours}h" : "${d.inHours}h ${minutes}m";
    }
    if (d.inDays < 7) return d.inDays == 1 ? "1 day" : "${d.inDays} days";
    final int weeks = (d.inDays / 7).floor();
    if (weeks < 5) return weeks == 1 ? "1 week" : "$weeks weeks";
    final int months = (d.inDays / 30).floor();
    return months <= 1 ? "1 month" : "$months months";
  }

  /// Strips the scheme and `www.` so a YouTube URL fits on a card line
  /// without an ellipsis eating the video id.
  static String shortLink(String url) {
    String out = url.trim();
    out = out.replaceFirst(RegExp(r'^https?://'), '');
    out = out.replaceFirst(RegExp(r'^www\.'), '');
    return out;
  }
}
