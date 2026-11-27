import 'package:bbarna/core/widgets/card/card_chips.dart';
import 'package:bbarna/core/widgets/list_page/admin_table.dart';
import 'package:bbarna/core/widgets/list_page/table_cells.dart';
import 'package:bbarna/core/widgets/list_page/table_identity.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/transactions/model/transaction_model.dart';
import 'package:bbarna/transactions/widgets/transaction_details_dialog.dart';
import 'package:bbarna/utils/money.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The purchases on wide screens: when, who (and their phone), which
/// subject, coupon, how it was paid, and what was paid with the full price
/// struck through. A row opens the receipt.
class TransactionTable extends StatelessWidget {
  /// The purchases shown, already searched and filtered.
  final List<TransactionModel> transactions;

  const TransactionTable({required this.transactions, super.key});

  /// Narrowest list width the table is used at (cards below it).
  static const double minWidth = 860;

  static const List<AdminTableColumn> _columns = [
    AdminTableColumn("Date", width: 110),
    AdminTableColumn("Student", flex: 4),
    AdminTableColumn("Subject", flex: 4),
    AdminTableColumn("Coupon", width: 120),
    AdminTableColumn("Method", width: 96),
    AdminTableColumn("Paid", width: 104, alignment: Alignment.centerRight),
  ];

  @override
  Widget build(BuildContext context) {
    return AdminTable(
      // It sits in the page's own scroll view (with the totals above).
      scrollable: false,
      columns: _columns,
      rowCount: transactions.length,
      rowKey: (i) => ValueKey('transaction_table_row_${transactions[i].docId}'),
      onRowTap: (i) => TransactionDetailsDialog.show(context, transactions[i]),
      cellsBuilder: (context, i, hovered) {
        final TransactionModel t = transactions[i];
        final DateTime? at = t.createdAt?.toLocal();
        return [
          _twoLines(at == null ? "Just now" : DateFormat('d MMM y').format(at),
              at == null ? null : DateFormat('h:mm a').format(at)),
          _twoLines(t.studentName, t.phone),
          _twoLines(t.subjectName, t.courseType),
          TableIdentity.hasText(t.couponCode)
              ? CodeChip(t.couponCode!)
              : const TableText(null),
          t.isFree
              ? const StatusPill("Free")
              : const StatusPill("Razorpay", tone: StatusTone.info),
          _paid(t),
        ];
      },
    );
  }

  /// A value with a muted line under it.
  static Widget _twoLines(String top, String? bottom) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(TableIdentity.hasText(top) ? top : "—",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppTokens.ink)),
        if (TableIdentity.hasText(bottom))
          Text(bottom!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 11.5, color: AppTokens.inkFaint)),
      ],
    );
  }

  /// Amount paid, with the full price struck through when it was less.
  static Widget _paid(TransactionModel t) {
    final bool discounted = t.coursePrice > t.amountPaid && t.coursePrice > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(formatRupees(t.amountPaid),
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppTokens.ink)),
        if (discounted)
          Text(formatRupees(t.coursePrice),
              style: const TextStyle(
                  fontSize: 11.5,
                  color: AppTokens.inkFaint,
                  decoration: TextDecoration.lineThrough)),
      ],
    );
  }
}
