import 'package:intl/intl.dart';

/// Rupee amount as text with Indian digit grouping: `₹349`, `₹1,248`,
/// `₹349.50`.
String formatRupees(double value) {
  final NumberFormat format = NumberFormat.decimalPattern('en_IN');
  if (value == value.roundToDouble()) {
    return '₹${format.format(value.toInt())}';
  }
  return '₹${NumberFormat('#,##,##0.00', 'en_IN').format(value)}';
}
