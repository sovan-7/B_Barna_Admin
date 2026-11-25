import 'package:bbarna/transactions/model/transaction_model.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

/// Spreadsheet text for [items], one row per purchase.
String transactionsCsv(List<TransactionModel> items) {
  final DateFormat date = DateFormat('yyyy-MM-dd HH:mm');
  return const ListToCsvConverter().convert([
    const [
      "Date",
      "Student",
      "Phone",
      "Course",
      "Type",
      "Price",
      "Offer discount",
      "Coupon",
      "Coupon discount",
      "Amount paid",
      "Method",
      "Payment ID",
      "Receipt no",
    ],
    for (final TransactionModel t in items)
      [
        t.createdAt == null ? "" : date.format(t.createdAt!),
        safeCsvText(t.studentName),
        safeCsvText(t.phone),
        safeCsvText(t.subjectName),
        safeCsvText(t.courseType),
        t.coursePrice,
        t.offerDiscount,
        safeCsvText(t.couponCode ?? ""),
        t.couponDiscount,
        t.amountPaid,
        safeCsvText(t.method),
        safeCsvText(t.paymentId ?? ""),
        safeCsvText(t.receiptNo),
      ],
  ]);
}

/// Students type their own names, and a spreadsheet runs any cell starting
/// with one of these as a formula. A leading apostrophe makes it plain text.
String safeCsvText(String text) {
  if (text.isEmpty) return text;
  const String risky = "=+-@\t\r";
  return risky.contains(text[0]) ? "'$text" : text;
}
