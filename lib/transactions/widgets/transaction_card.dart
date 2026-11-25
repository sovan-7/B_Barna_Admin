import 'package:bbarna/core/widgets/card/admin_card_shell.dart';
import 'package:bbarna/core/widgets/card/card_chips.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/transactions/model/transaction_model.dart';
import 'package:bbarna/transactions/widgets/transaction_details_dialog.dart';
import 'package:bbarna/utils/money.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// One purchase: who bought what and when, what they paid, and whether it
/// was paid or free. Tapping it opens the details.
class TransactionCard extends StatelessWidget {
  /// The purchase shown in this row.
  final TransactionModel transaction;

  const TransactionCard({required this.transaction, super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('transaction_row_${transaction.docId}'),
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      onTap: () => TransactionDetailsDialog.show(context, transaction),
      child: AdminCardShell(
        builder: (context, layout) => CardRowLayout(
          layout: layout,
          identity: _identity(),
          // Right-aligned on wide screens, so every row's arrow lines up.
          chips: layout.isCompact
              ? _chips()
              : Align(alignment: Alignment.centerRight, child: _chips()),
          actions: const Icon(Icons.chevron_right,
              size: 20, color: AppTokens.inkFaint),
        ),
      ),
    );
  }

  /// Course and date, then the student.
  Widget _identity() {
    final TransactionModel t = transaction;
    final DateTime? at = t.createdAt;
    final String date =
        at == null ? "Just now" : DateFormat('d MMM yyyy, h:mm a').format(at);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.subjectName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AppTokens.ink),
        ),
        const SizedBox(height: 4),
        Text(
          "${t.studentName} · ${t.phone}",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTokens.body,
        ),
        const SizedBox(height: 2),
        Text(date,
            style: const TextStyle(fontSize: 12, color: AppTokens.inkFaint)),
      ],
    );
  }

  /// Paid or free, the amount, and the coupon if one was used.
  Widget _chips() {
    final TransactionModel t = transaction;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        StatusChip(
          icon: t.isFree ? Icons.card_giftcard : Icons.check_circle_outline,
          label: t.isFree ? "Free" : "Paid",
          color: t.isFree ? AppTokens.inkMuted : const Color(0xFF108460),
          filled: !t.isFree,
        ),
        StatusChip(
          icon: Icons.payments_outlined,
          label: formatRupees(t.amountPaid),
          color: AppTokens.ink,
        ),
        if ((t.couponCode ?? "").isNotEmpty)
          StatusChip(
            icon: Icons.sell_outlined,
            label: t.couponCode!,
            color: AppTokens.inkMuted,
          ),
      ],
    );
  }
}
