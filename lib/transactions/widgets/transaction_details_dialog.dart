import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/transactions/model/transaction_model.dart';
import 'package:bbarna/transactions/transaction_pdf.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:bbarna/utils/money.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Everything recorded about one purchase, with its receipt as a PDF.
class TransactionDetailsDialog extends StatefulWidget {
  /// The purchase shown.
  final TransactionModel transaction;

  const TransactionDetailsDialog({required this.transaction, super.key});

  /// Opens the dialog for [transaction].
  static Future<void> show(BuildContext context, TransactionModel transaction) {
    return showDialog<void>(
      context: context,
      builder: (_) => TransactionDetailsDialog(transaction: transaction),
    );
  }

  @override
  State<TransactionDetailsDialog> createState() =>
      _TransactionDetailsDialogState();
}

class _TransactionDetailsDialogState extends State<TransactionDetailsDialog> {
  /// True while the receipt is being made.
  bool _saving = false;

  TransactionModel get _t => widget.transaction;

  Future<void> _downloadReceipt() async {
    setState(() => _saving = true);
    try {
      final Uint8List bytes = await TransactionPdf.receipt(_t);
      final String name = "${TransactionPdf.receiptFileName(_t)}.pdf";
      await FilePicker.platform.saveFile(
        dialogTitle: "Save $name",
        fileName: name,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        bytes: bytes,
      );
    } catch (_) {
      Helper.showSnackBarMessage(
          msg: "Couldn't save the receipt", isSuccess: false);
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _copyPaymentId() async {
    await Clipboard.setData(ClipboardData(text: _t.paymentId ?? ""));
    Helper.showSnackBarMessage(msg: "Payment ID copied", isSuccess: true);
  }

  @override
  Widget build(BuildContext context) {
    final DateTime? at = _t.createdAt;

    return AlertDialog(
      backgroundColor: AppTokens.surface,
      surfaceTintColor: AppTokens.surface,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formatRupees(_t.amountPaid),
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTokens.ink)),
          const SizedBox(height: 2),
          Text(_t.isFree ? "Enrolled for free" : "Payment successful",
              style: AppTokens.pageSubtitle),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _row(
                  "Date",
                  at == null
                      ? "Just now"
                      : DateFormat('d MMM yyyy, h:mm a').format(at)),
              _row("Student", _t.studentName),
              _row("Phone", _t.phone),
              _row("Course", _t.subjectName),
              if (_t.courseType.isNotEmpty) _row("Type", _t.courseType),
              _row("Course price", formatRupees(_t.coursePrice)),
              if (_t.offerDiscount > 0)
                _row("Offer discount", "- ${formatRupees(_t.offerDiscount)}"),
              if (_t.couponDiscount > 0)
                _row("Coupon ${_t.couponCode ?? ""}".trim(),
                    "- ${formatRupees(_t.couponDiscount)}"),
              _row("Method", _t.method),
              _row("Receipt no.", _t.receiptNo),
              if (_t.paymentId != null)
                _row("Payment ID", _t.paymentId!,
                    trailing: IconButton(
                      key: const Key('transaction_copy_payment_id'),
                      tooltip: "Copy payment ID",
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.copy, size: 15),
                      onPressed: _copyPaymentId,
                    )),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppTokens.ink),
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
        FilledButton.icon(
          key: const Key('transaction_download_receipt'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTokens.ink,
            foregroundColor: AppTokens.surface,
          ),
          onPressed: _saving ? null : _downloadReceipt,
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download, size: 17),
          label: const Text("Download receipt PDF"),
        ),
      ],
    );
  }

  /// A label on the left and its selectable value on the right.
  Widget _row(String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style:
                    const TextStyle(fontSize: 13, color: AppTokens.inkMuted)),
          ),
          Expanded(
            // Not SelectableLabel: its maxLines reserves that many lines'
            // height, which spreads these rows far apart.
            child: SelectableText(value, style: AppTokens.body),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
