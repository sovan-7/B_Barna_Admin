import 'package:flutter/material.dart';

/// Small date/time helpers for scheduling a live class, which always runs
/// within a single day (one date + a start and an end time).
class ClassTime {
  const ClassTime._();

  /// [value] with the time of day stripped (midnight).
  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// Whether [a] and [b] fall on the same calendar day.
  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Minutes since midnight.
  static int minutesOf(TimeOfDay time) => time.hour * 60 + time.minute;

  /// [start] advanced by [minutes], or null if that would pass midnight.
  static TimeOfDay? plus(TimeOfDay start, int minutes) {
    final int total = minutesOf(start) + minutes;
    if (total >= 24 * 60) return null;
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }

  /// [date] at [time], or null if either is missing.
  static DateTime? combine(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}
