import 'package:bbarna/transactions/model/transaction_model.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The PDFs of the Transactions module, in the same style as the ones
/// students get from the app (`receipt_pdf.dart` and `history_pdf.dart`
/// there): one purchase's receipt, and a statement of many purchases.
///
/// Uses the bundled Noto Sans, because a PDF's built-in fonts have no ₹.
class TransactionPdf {
  const TransactionPdf._();

  static const String _support = '+91 70017 39646';
  static const String _website = 'www.bbarna.in';

  static const PdfColor _brand = PdfColor.fromInt(0xFF0A2A6B);
  static const PdfColor _muted = PdfColor.fromInt(0xFF8A8A93);
  static const PdfColor _ink = PdfColor.fromInt(0xFF1C1C1E);
  static const PdfColor _line = PdfColor.fromInt(0xFFD1D1D6);
  static const PdfColor _green = PdfColor.fromInt(0xFF1F7A5A);
  static const PdfColor _shade = PdfColor.fromInt(0xFFF1EFE8);
  static const PdfColor _altRow = PdfColor.fromInt(0xFFFAF9F6);

  /// 12500.0 -> "₹ 12,500" (Indian digit grouping), 499.5 -> "₹ 499.5".
  static String money(double value) {
    final NumberFormat format = NumberFormat.decimalPattern('en_IN');
    if (value == value.roundToDouble()) {
      return '₹ ${format.format(value.toInt())}';
    }
    return '₹ ${format.format(value)}';
  }

  static String _dateTime(DateTime? date) {
    if (date == null) return 'Just now';
    return DateFormat('d MMM yyyy, h:mm a').format(date);
  }

  /// The file name of [t]'s receipt, without the extension.
  static String receiptFileName(TransactionModel t) =>
      'B_Barna_Receipt_${t.receiptNo.isEmpty ? t.docId : t.receiptNo}';

  /// The file name of a statement made at [now], without the extension.
  static String statementFileName(DateTime now) =>
      'B_Barna_Transactions_${DateFormat('yyyyMMdd').format(now)}';

  // ---- Shared -------------------------------------------------------------

  static Future<pw.ThemeData> _theme() async {
    final pw.Font regular =
        pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    final pw.Font bold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
    return pw.ThemeData.withFont(base: regular, bold: bold).copyWith(
      defaultTextStyle: pw.TextStyle(font: regular, fontSize: 10, color: _ink),
    );
  }

  static Future<pw.MemoryImage> _logo() async {
    final ByteData data = await rootBundle.load('assets/images/logo.png');
    return pw.MemoryImage(data.buffer.asUint8List());
  }

  /// Logo and brand on the left, [title] and [subtitle] on the right, then
  /// a line in the brand colour.
  static pw.Widget _header(pw.MemoryImage logo, String title, String subtitle) {
    final pw.TextStyle strong = pw.TextStyle(fontWeight: pw.FontWeight.bold);
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Image(logo, width: 40, height: 40),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('B_Barna',
                      style: strong.copyWith(fontSize: 20, color: _brand)),
                  pw.Text('$_website  ·  $_support',
                      style: const pw.TextStyle(fontSize: 9, color: _muted)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(title, style: strong.copyWith(fontSize: 13)),
                pw.Text(subtitle,
                    style: const pw.TextStyle(fontSize: 9, color: _muted)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Container(height: 2, color: _brand),
        pw.SizedBox(height: 14),
      ],
    );
  }

  /// "History (Full Course)".
  static String _courseLabel(TransactionModel t) {
    if (t.courseType.isEmpty) return t.subjectName;
    return '${t.subjectName} (${t.courseType})';
  }

  // ---- Receipt ------------------------------------------------------------

  /// One purchase's receipt.
  static Future<Uint8List> receipt(TransactionModel t) async {
    final pw.ThemeData theme = await _theme();
    final pw.MemoryImage logo = await _logo();

    final pw.Document doc =
        pw.Document(title: 'B_Barna receipt ${t.receiptNo}', author: 'B_Barna');
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      theme: theme,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _header(logo, 'PAYMENT RECEIPT', t.receiptNo),
          _infoRow('Billed to', t.studentName),
          _infoRow('Phone', '+91 ${t.phone}'),
          _infoRow('Date', _dateTime(t.createdAt)),
          _infoRow('Payment method', t.isFree ? 'Free enrolment' : t.method),
          if (t.paymentId != null) _infoRow('Payment ID', t.paymentId!),
          pw.SizedBox(height: 18),
          _itemTable(t),
          pw.SizedBox(height: 24),
          _stamp(t),
          pw.Spacer(),
          pw.Container(height: 0.8, color: _line),
          pw.SizedBox(height: 8),
          pw.Text(
            'This is a computer-generated receipt and needs no signature.',
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),
          pw.Text(
            '${t.isFree ? 'Free enrolment.' : 'Paid via Razorpay.'} '
            'For help, WhatsApp $_support.',
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),
        ],
      ),
    ));
    return doc.save();
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(color: _muted)),
          pw.Text(value),
        ],
      ),
    );
  }

  static pw.Widget _itemTable(TransactionModel t) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line, width: 0.8),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        children: [
          _itemRow('Item', 'Amount', strong: true, shaded: true),
          _itemRow(_courseLabel(t), money(t.coursePrice)),
          if (t.offerDiscount > 0)
            _itemRow('Offer discount', '- ${money(t.offerDiscount)}',
                color: _green),
          if (t.couponDiscount > 0)
            _itemRow('Coupon ${t.couponCode ?? ''}'.trim(),
                '- ${money(t.couponDiscount)}',
                color: _green),
          pw.Container(height: 0.8, color: _line),
          _itemRow('Total paid', money(t.amountPaid), strong: true),
        ],
      ),
    );
  }

  static pw.Widget _itemRow(String label, String value,
      {bool strong = false, PdfColor? color, bool shaded = false}) {
    final pw.TextStyle style = pw.TextStyle(
      fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color,
    );
    return pw.Container(
      color: shaded ? _shade : null,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(label, style: style)),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  /// A green "PAID" (or "FREE") stamp, slightly tilted.
  static pw.Widget _stamp(TransactionModel t) {
    return pw.Transform.rotate(
      angle: 0.07,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _green, width: 2),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(t.isFree ? 'FREE' : 'PAID',
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 16,
                color: _green,
                letterSpacing: 2)),
      ),
    );
  }

  // ---- Statement ----------------------------------------------------------

  /// A statement of [items], with the totals on top. [now] is shown as when
  /// it was made. Long lists flow onto more pages; the header, the column
  /// titles and the footer repeat.
  static Future<Uint8List> statement(
    List<TransactionModel> items, {
    required double totalCollected,
    required double totalDiscounts,
    required DateTime now,
  }) async {
    final pw.ThemeData theme = await _theme();
    final pw.MemoryImage logo = await _logo();
    final int free = items.where((t) => t.isFree).length;

    final pw.Document doc =
        pw.Document(title: 'B_Barna transactions', author: 'B_Barna');
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 28),
      theme: theme,
      header: (_) =>
          _header(logo, 'TRANSACTIONS', 'Generated ${_dateTime(now)}'),
      footer: _footer,
      build: (_) => [
        pw.Row(
          children: [
            _summaryBox('Collected', money(totalCollected), _brand),
            pw.SizedBox(width: 8),
            _summaryBox('Paid', '${items.length - free}', _ink),
            pw.SizedBox(width: 8),
            _summaryBox('Free', '$free', _ink),
            pw.SizedBox(width: 8),
            _summaryBox('Discounts', money(totalDiscounts), _green),
          ],
        ),
        pw.SizedBox(height: 16),
        _statementTable(items),
      ],
    ));
    return doc.save();
  }

  static pw.Widget _summaryBox(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _line, width: 0.8),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: const pw.TextStyle(fontSize: 9, color: _muted)),
            pw.SizedBox(height: 2),
            pw.Text(value,
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13,
                    color: color)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _statementTable(List<TransactionModel> items) {
    return pw.Table(
      columnWidths: const {
        0: pw.FixedColumnWidth(66),
        1: pw.FixedColumnWidth(92),
        2: pw.FlexColumnWidth(),
        3: pw.FixedColumnWidth(58),
        4: pw.FixedColumnWidth(38),
      },
      children: [
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: _shade),
          children: [
            _headCell('Date'),
            _headCell('Student'),
            _headCell('Course and receipt'),
            _headCell('Amount', right: true),
            _headCell('Status', right: true),
          ],
        ),
        for (int i = 0; i < items.length; i++) _statementRow(items[i], i),
      ],
    );
  }

  static pw.TableRow _statementRow(TransactionModel t, int index) {
    const pw.TextStyle small = pw.TextStyle(fontSize: 8.5, color: _muted);
    final DateTime? at = t.createdAt;
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: index.isOdd ? _altRow : null,
        border:
            const pw.Border(bottom: pw.BorderSide(color: _line, width: 0.5)),
      ),
      children: [
        _cell(pw.Text(
            at == null
                ? 'Just now'
                : DateFormat('d MMM yyyy\nh:mm a').format(at),
            style: const pw.TextStyle(fontSize: 8.5))),
        _cell(pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(t.studentName, style: const pw.TextStyle(fontSize: 9)),
            pw.Text(t.phone, style: small),
          ],
        )),
        _cell(pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(_courseLabel(t), style: const pw.TextStyle(fontSize: 9)),
            if (t.couponDiscount > 0)
              pw.Text(
                  'Coupon ${t.couponCode ?? ''}  - ${money(t.couponDiscount)}',
                  style: const pw.TextStyle(fontSize: 8.5, color: _green)),
            pw.Text(t.receiptNo, style: small),
          ],
        )),
        _cell(
            pw.Text(money(t.amountPaid),
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            right: true),
        _cell(
            pw.Text(t.isFree ? 'FREE' : 'PAID',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8,
                    color: t.isFree ? _muted : _green)),
            right: true),
      ],
    );
  }

  static pw.Widget _headCell(String text, {bool right = false}) {
    return _cell(
      pw.Text(text,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
      right: right,
    );
  }

  static pw.Widget _cell(pw.Widget child, {bool right = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: pw.Align(
        alignment: right ? pw.Alignment.topRight : pw.Alignment.topLeft,
        child: child,
      ),
    );
  }

  static pw.Widget _footer(pw.Context context) {
    const pw.TextStyle style = pw.TextStyle(fontSize: 8, color: _muted);
    return pw.Column(
      children: [
        pw.Container(height: 0.8, color: _line),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Expanded(
                child: pw.Text('Computer-generated statement.', style: style)),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                style: style),
          ],
        ),
      ],
    );
  }
}
