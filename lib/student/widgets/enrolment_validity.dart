import 'package:intl/intl.dart';

/// How long an enrolment has left, and when it runs out. Pure functions,
/// so the date arithmetic can be unit-tested.
class EnrolmentValidity {
  const EnrolmentValidity._();

  static final DateFormat _date = DateFormat("d MMM yyyy");

  /// True for a timestamp this codebase would treat as unset.
  static bool isUnset(int millis) => millis.toString().length <= 10;

  /// "14 Mar 2026", or null when the stored value is not a real date.
  static String? formatDate(int millis) {
    if (isUnset(millis)) return null;
    try {
      return _date.format(DateTime.fromMillisecondsSinceEpoch(millis));
    } catch (_) {
      return null;
    }
  }

  static bool hasExpired(int millis, {DateTime? now}) {
    if (isUnset(millis)) return false;
    return DateTime.fromMillisecondsSinceEpoch(millis)
        .isBefore(now ?? DateTime.now());
  }

  /// "1 year 2 months 3 days left", or "Expired" once it is past; null when
  /// the date is unset.
  static String? formatRemaining(int millis, {DateTime? now}) {
    if (isUnset(millis)) return null;

    final DateTime target = DateTime.fromMillisecondsSinceEpoch(millis);
    final Duration difference = target.difference(now ?? DateTime.now());
    if (difference.isNegative) return "Expired";

    final int totalDays = difference.inDays;
    if (totalDays == 0) return "Less than a day left";

    final int years = totalDays ~/ 365;
    final int months = (totalDays % 365) ~/ 30;
    final int days = (totalDays % 365) % 30;

    final List<String> parts = [
      if (years > 0) "$years year${years == 1 ? '' : 's'}",
      if (months > 0) "$months month${months == 1 ? '' : 's'}",
      // Days are noise next to a year, but they are the whole story when
      // that is all there is.
      if (days > 0 && years == 0) "$days day${days == 1 ? '' : 's'}",
    ];
    return "${parts.join(' ')} left";
  }
}
