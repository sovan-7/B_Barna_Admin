import 'package:bbarna/core/widgets/list_page/paged_list_screen.dart';
import 'package:bbarna/documents/pdf/model/pdf_model.dart';
import 'package:bbarna/documents/pdf/screen/add_pdf.dart';
import 'package:bbarna/documents/pdf/viewModel/pdf_view_model.dart';
import 'package:bbarna/documents/pdf/widgets/pdf_card.dart';
import 'package:flutter/material.dart';

/// The PDF list (sidebar module). All the behaviour lives in
/// [PagedListScreen]; this only supplies the PDF-specific texts and card.
class PDFList extends StatelessWidget {
  const PDFList({super.key});

  @override
  Widget build(BuildContext context) {
    return PagedListScreen<PdfViewModel, PdfModel>(
      title: "PDFs",
      subtitle: "Newest first. Free PDFs open without a purchase.",
      addButtonLabel: "NEW PDF",
      addScreenBuilder: (context) => const AddPdf(),
      searchHint: "Search by PDF code",
      skeletonRowHeight: 88,
      emptyIcon: Icons.picture_as_pdf_outlined,
      emptyTitle: "No PDFs yet",
      emptyMessage: "Upload a PDF and students can read it inside the app.",
      filteredMessage:
          "No PDF code starts with that. Search matches the code, not the title.",
      emptyAddLabel: "Add a PDF",
      itemBuilder: (context, pdf, onChanged) => PdfCard(
        key: ValueKey(pdf.docId),
        pdfData: pdf,
        onChanged: onChanged,
      ),
    );
  }
}
