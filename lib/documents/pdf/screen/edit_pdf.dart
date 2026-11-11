import 'package:bbarna/documents/pdf/model/pdf_model.dart';
import 'package:bbarna/documents/pdf/widgets/pdf_form.dart';
import 'package:flutter/material.dart';

/// Edit PDF screen — the shared [PdfForm] pre-populated with [pdfData];
/// also offers Delete.
class EditPdf extends StatelessWidget {
  /// The item being edited.
  final PdfModel pdfData;
  const EditPdf({required this.pdfData, super.key});

  @override
  Widget build(BuildContext context) => PdfForm(existing: pdfData);
}
