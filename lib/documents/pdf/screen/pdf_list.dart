import 'package:bbarna/core/widgets/list_page/paged_list_screen.dart';
import 'package:bbarna/documents/pdf/model/pdf_model.dart';
import 'package:bbarna/documents/pdf/screen/add_pdf.dart';
import 'package:bbarna/documents/pdf/viewModel/pdf_view_model.dart';
import 'package:bbarna/documents/pdf/widgets/pdf_card.dart';
import 'package:bbarna/core/widgets/card/card_chips.dart';
import 'package:bbarna/documents/media_table.dart';
import 'package:bbarna/core/widgets/list_page/admin_table.dart';
import 'package:bbarna/core/widgets/list_page/table_cells.dart';
import 'package:provider/provider.dart';
import 'package:bbarna/resources/app_tokens.dart';
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
      statTiles: (vm) => mediaStatTiles("pdf", vm.totalCount, vm.stats),
      chipOptions: accessChipOptions("pdf"),
      chipMatches: (pdf, filter) => accessChipMatches(pdf.pdfType, filter),
      tableColumns: mediaColumns("PDF", extra: const [
        AdminTableColumn("Download", width: 76, alignment: Alignment.center),
        AdminTableColumn("Locked", width: 60),
      ]),
      rowId: (pdf) => pdf.docId,
      rowKeyPrefix: "pdf",
      tableMinWidth: 860,
      rowCells: (context, pdf, hovered, onChanged) => [
        mediaIdentity(
            title: pdf.title,
            description: pdf.description,
            icon: Icons.picture_as_pdf_outlined,
            color: const Color(0xFFA32D2D)),
        CodeChip(pdf.code, copyable: true),
        accessPill(pdf.pdfType),
        Selector<PdfViewModel, bool>(
          selector: (_, vm) => vm.isFlagBusy(pdf.docId, "is_downloadable"),
          builder: (context, busy, _) => FlagIconToggle(
            buttonKey: Key('pdf_downloadable_${pdf.docId}'),
            on: pdf.isDownloadable,
            onIcon: Icons.download_rounded,
            offIcon: Icons.file_download_off_outlined,
            onColor: AppTokens.accent,
            onTooltip: "Downloadable — make it view-only",
            offTooltip: "View only — allow downloads",
            busy: busy,
            onTap: () => Provider.of<PdfViewModel>(context, listen: false)
                .toggleDownloadable(pdf),
          ),
        ),
        Selector<PdfViewModel, bool>(
          selector: (_, vm) => vm.isFlagBusy(pdf.docId, "is_locked"),
          builder: (context, busy, _) => LockSwitch(
            switchKey: Key('pdf_lock_${pdf.docId}'),
            locked: pdf.isLocked,
            busy: busy,
            itemLabel: "this PDF",
            onChanged: (_) => Provider.of<PdfViewModel>(context, listen: false)
                .toggleLocked(pdf),
          ),
        ),
        addedCell(pdf.timeStamp),
        openLinkCell(pdf.pdfLink, Key('pdf_open_${pdf.docId}'), "Open the PDF"),
        pdfActions(context, pdf, onChanged, hovered),
      ],
    );
  }
}
