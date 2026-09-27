import 'package:intl/intl.dart';

/// How a student's last sign-in reads on their row.
///
/// Extracted so the wording and the day arithmetic can be tested without a
/// widget — the same reason [EnrolmentValidity] lives on its own.
class StudentActivity {
  const StudentActivity._();

  /// Format for "Active 12 Mar 2026" (created once, not per row).
  static final DateFormat _date = DateFormat('d MMM yyyy');

  /// A short label for [lastLoginAt], or null when the student has never
  /// signed in.
  ///
  /// Counted in whole calendar days, not elapsed hours: 11pm last night and
  /// 1am this morning are "Yesterday" and "Today", which is what an admin
  /// scanning the list means by them. `difference().inDays` would call both
  /// "0 days" and read them as today.
  static String? lastActiveLabel(DateTime? lastLoginAt, {DateTime? now}) {
    if (lastLoginAt == null) return null;

    final DateTime at = now ?? DateTime.now();
    final DateTime today = DateTime(at.year, at.month, at.day);
    final DateTime day =
        DateTime(lastLoginAt.year, lastLoginAt.month, lastLoginAt.day);
    final int days = today.difference(day).inDays;

    // A clock skewed ahead of the server, or a login stamped in the future.
    // "In 2 days" would be nonsense on a *last* seen label.
    if (days < 0) return "Active today";

    if (days == 0) return "Active today";
    if (days == 1) return "Active yesterday";
    if (days < 7) return "Active $days days ago";
    if (days < 30) {
      final int weeks = days ~/ 7;
      return "Active $weeks week${weeks == 1 ? '' : 's'} ago";
    }
    // Past a month the exact date is more use than "5 weeks ago".
    return "Active ${_date.format(lastLoginAt)}";
  }

  /// What the row says when there is no sign-in to report.
  static const String neverLabel = "Never signed in";
}
