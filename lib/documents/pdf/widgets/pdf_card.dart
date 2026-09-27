import 'package:bbarna/core/widgets/card/admin_card_shell.dart';
import 'package:bbarna/core/widgets/card/card_actions.dart';
import 'package:bbarna/core/widgets/card/card_chips.dart';
import 'package:bbarna/core/widgets/card/card_helpers.dart';
import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/documents/pdf/model/pdf_model.dart';
import 'package:bbarna/documents/pdf/screen/edit_pdf.dart';
import 'package:bbarna/documents/pdf/viewModel/pdf_view_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/navigation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// One row of the PDF list: file icon, title, code, description and an
/// "Open the file" link; FREE/PAID, downloadable and lock chips (the last
/// two are tappable toggles); and edit / delete buttons.
class PdfCard extends StatelessWidget {
  /// The PDF shown in this row.
  final PdfModel pdfData;

  /// Called after an edit or delete so the list can reload.
  final VoidCallback onChanged;

  const PdfCard({required this.pdfData, required this.onChanged, super.key});

  /// Shortcut for the item shown.
  PdfModel get _data => pdfData;

  @override
  Widget build(BuildContext context) {
    return AdminCardShell(
      builder: (context, layout) => CardRowLayout(
        layout: layout,
        identity: _identity(),
        chips: _chips(context),
        actions: _actions(context, layout.showActions),
      ),
    );
  }

  /// File icon (red when a file is attached), title + code, description,
  /// and the "Open the file" link or a "No file uploaded" warning.
  Widget _identity() {
    final bool hasDescription = _data.description.trim().isNotEmpty &&
        _data.description != stringDefault;
    final bool hasFile =
        _data.pdfLink.trim().isNotEmpty && _data.pdfLink != stringDefault;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: AppTokens.surfaceMuted,
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            border: Border.all(color: AppTokens.hairline),
          ),
          child: Icon(Icons.picture_as_pdf_outlined,
              size: 20,
              color: hasFile ? const Color(0xFFD92D20) : AppTokens.inkFaint),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: SelectableLabel(
                      _data.title,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppTokens.ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CodeChip(_data.code),
                ],
              ),
              if (hasDescription) ...[
                const SizedBox(height: 4),
                Text(_data.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTokens.body),
              ],
              const SizedBox(height: 6),
              if (hasFile)
                Row(
                  children: [
                    const Icon(Icons.attach_file,
                        size: 13, color: AppTokens.inkFaint),
                    const SizedBox(width: 5),
                    InkWell(
                      key: Key('pdf_open_${_data.docId}'),
                      onTap: () => openExternalUrl(_data.pdfLink,
                          failureMessage: "Could not open that file"),
                      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Text("Open the file",
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2563EB))),
                            SizedBox(width: 4),
                            Icon(Icons.open_in_new,
                                size: 12, color: Color(0xFF2563EB)),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              else
                const Text("No file uploaded",
                    style: TextStyle(fontSize: 11.5, color: AppTokens.danger)),
            ],
          ),
        ),
      ],
    );
  }

  /// FREE/PAID status, plus the downloadable and lock toggles.
  Widget _chips(BuildContext context) {
    final bool isFree = _data.pdfType.toUpperCase() == "FREE";
    final Color typeColor =
        isFree ? const Color(0xFF108460) : const Color(0xFFB54708);
    final PdfViewModel pdfViewModel =
        Provider.of<PdfViewModel>(context, listen: false);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        StatusChip(
          icon: isFree ? Icons.lock_open_outlined : Icons.paid_outlined,
          label: _data.pdfType.isEmpty || _data.pdfType == stringDefault
              ? "No type"
              : _data.pdfType.toUpperCase(),
          color: typeColor,
          filled: true,
        ),
        // Rebuilds just this chip while its write is in flight.
        Selector<PdfViewModel, bool>(
          selector: (_, vm) => vm.isFlagBusy(_data.docId, "is_downloadable"),
          builder: (context, busy, _) => ToggleChip(
            buttonKey: Key('pdf_downloadable_${_data.docId}'),
            icon: _data.isDownloadable
                ? Icons.download_outlined
                : Icons.visibility_outlined,
            label: _data.isDownloadable ? "Downloadable" : "View only",
            on: _data.isDownloadable,
            onColor: const Color(0xFF2563EB),
            tooltip:
                _data.isDownloadable ? "Make it view-only" : "Allow downloads",
            onTap: () => pdfViewModel.toggleDownloadable(_data),
            busy: busy,
          ),
        ),
        // Rebuilds just this chip while its write is in flight.
        Selector<PdfViewModel, bool>(
          selector: (_, vm) => vm.isFlagBusy(_data.docId, "is_locked"),
          builder: (context, busy, _) => ToggleChip(
            buttonKey: Key('pdf_lock_${_data.docId}'),
            icon: _data.isLocked
                ? Icons.lock_outline_rounded
                : Icons.lock_open_outlined,
            label: _data.isLocked ? "Locked" : "Unlocked",
            on: _data.isLocked,
            onColor: const Color(0xFFB54708),
            tooltip: _data.isLocked ? "Unlock this PDF" : "Lock this PDF",
            onTap: () => pdfViewModel.toggleLocked(_data),
            busy: busy,
          ),
        ),
      ],
    );
  }

  /// Edit and delete buttons.
  Widget _actions(BuildContext context, bool visible) {
    return CardActions(
      visible: visible,
      buttons: [
        CardEditButton(
          buttonKey: Key('pdf_edit_${_data.docId}'),
          tooltip: "Edit PDF",
          onTap: () => _openEdit(context),
        ),
        CardDeleteButton(
          buttonKey: Key('pdf_delete_${_data.docId}'),
          tooltip: "Delete PDF",
          onTap: () => _confirmDelete(context),
        ),
      ],
    );
  }

  /// Opens Edit PDF; the list reloads if it saved or deleted something.
  void _openEdit(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditPdf(pdfData: _data)),
    ).ifSaved(onChanged);
  }

  /// Asks for confirmation, deletes, then reloads the list.
  void _confirmDelete(BuildContext context) {
    final PdfViewModel pdfViewModel =
        Provider.of<PdfViewModel>(context, listen: false);
    final String docId = _data.docId;

    confirmDelete(
      title: _data.title,
      delete: () => pdfViewModel.deletePdf(docId),
      successMessage: "PDF deleted successfully",
    );
  }
}
