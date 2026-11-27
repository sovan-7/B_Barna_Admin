import 'dart:typed_data';

import 'package:bbarna/core/widgets/form/form_fields.dart';
import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/topic1/model/topic1_model.dart';
import 'package:bbarna/topic1/widgets/topic1_section_card.dart';
import 'package:bbarna/utils/formatters.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// A PDF chosen in the file picker.
typedef PickedPdf = ({Uint8List bytes, String name});

/// Opens the system file picker for one `.pdf` file; null when cancelled
/// (or when the file could not be read).
Future<PickedPdf?> pickPdfFile() async {
  final FilePickerResult? picked = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    withData: true,
  );
  final PlatformFile? file = picked?.files.firstOrNull;
  final Uint8List? bytes = file?.bytes;
  if (file == null || bytes == null) return null;
  return (bytes: bytes, name: file.name);
}

/// The fields of a PDF row that can carry an inline error.
enum _PdfField { title, file, type }

/// One row being edited: the saved entry it started from (if any), what
/// has been typed or toggled, and a newly picked file (if any).
class _PdfRow {
  /// [Topic1Pdf.id]; new rows get a fresh one.
  final String id;

  /// The saved entry this row edits; null for a row added here.
  final Topic1Pdf? existing;

  /// Title being typed.
  final TextEditingController title;

  /// "FREE" / "PAID", or null until chosen.
  String? type;

  /// Downloadable toggle.
  bool isDownloadable;

  /// A newly picked file, replacing [existing]'s.
  Uint8List? newBytes;

  /// Name of the newly picked file.
  String? newFileName;

  _PdfRow.fromPdf(Topic1Pdf pdf)
      : id = pdf.id,
        existing = pdf,
        title = TextEditingController(text: pdf.title),
        type = topic1AccessTypes.contains(pdf.type) ? pdf.type : null,
        isDownloadable = pdf.isDownloadable;

  _PdfRow.fresh()
      : id = newTopic1ItemId(),
        existing = null,
        title = TextEditingController(),
        type = null,
        isDownloadable = false;

  /// Whether the row has a file: a newly picked one or the saved one.
  bool get hasFile =>
      newBytes != null || (existing?.link ?? "").trim().isNotEmpty;

  /// The row as handed to `Topic1ViewModel.savePdfs`.
  Topic1PdfDraft toDraft() => Topic1PdfDraft(
        id: id,
        title: title.text.trim(),
        type: type ?? stringDefault,
        isDownloadable: isDownloadable,
        existing: existing,
        newBytes: newBytes,
        newFileName: newFileName,
      );
}

/// The PDFs on a Topic1: one row per PDF with its title, the uploaded file
/// (choose or replace), Free/Paid and Downloadable; "Add a PDF" and Save.
/// Files are uploaded only when Save is pressed. Saved rows open folded to
/// a one-line summary; tap one to edit it.
class Topic1PdfSection extends StatefulWidget {
  /// The PDFs currently saved on the topic.
  final List<Topic1Pdf> initialPdfs;

  /// Uploads new files and saves the rows. Returns the saved list (rows
  /// are then rebuilt from it), or null when the save failed.
  final Future<List<Topic1Pdf>?> Function(List<Topic1PdfDraft> drafts) onSave;

  /// Told whenever the section's unsaved state or row count changes (after
  /// the frame), so a tab can show "Unsaved changes" and a count. Optional.
  final void Function(bool dirty, int count)? onStateChanged;

  /// Picks a file; replaceable so tests need no real file picker.
  final Future<PickedPdf?> Function() pickFile;

  const Topic1PdfSection({
    required this.initialPdfs,
    required this.onSave,
    this.onStateChanged,
    this.pickFile = pickPdfFile,
    super.key,
  });

  @override
  State<Topic1PdfSection> createState() => _Topic1PdfSectionState();
}

class _Topic1PdfSectionState extends State<Topic1PdfSection> {
  /// The rows, in display order.
  final List<_PdfRow> _rows = [];

  /// Inline errors per row id: filled on a failed save, then refreshed on
  /// every change so each message clears as its field is fixed.
  final Map<String, Map<_PdfField, String>> _errors = {};

  /// True while the upload / save is in flight.
  bool _isSaving = false;

  /// True when the rows differ from what is saved.
  bool _dirty = false;

  /// Ids of the rows whose fields are showing. Saved rows start folded;
  /// added rows, and rows that fail a save, unfold.
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _resetRows(widget.initialPdfs);
  }

  @override
  void dispose() {
    for (final _PdfRow row in _rows) {
      row.title.dispose();
    }
    super.dispose();
  }

  /// Replaces the rows with [pdfs] (on open, and after a save).
  void _resetRows(List<Topic1Pdf> pdfs) {
    for (final _PdfRow row in _rows) {
      row.title.dispose();
    }
    _rows
      ..clear()
      ..addAll(pdfs.map(_PdfRow.fromPdf));
  }

  /// Every row's problems (rows without any are left out).
  Map<String, Map<_PdfField, String>> _validate() {
    final Map<String, Map<_PdfField, String>> errors = {};
    for (final _PdfRow row in _rows) {
      final Map<_PdfField, String> rowErrors = {};
      if (row.title.text.trim().isEmpty) {
        rowErrors[_PdfField.title] = "Give the PDF a title";
      }
      if (!row.hasFile) rowErrors[_PdfField.file] = "Choose a PDF file";
      if (row.type == null) {
        rowErrors[_PdfField.type] = "Choose whether it is free or paid";
      }
      if (rowErrors.isNotEmpty) errors[row.id] = rowErrors;
    }
    return errors;
  }

  /// Marks the rows changed and, once a save has failed, re-checks them.
  void _changed() {
    setState(() {
      _dirty = true;
      if (_errors.isNotEmpty) {
        _errors
          ..clear()
          ..addAll(_validate());
      }
    });
  }

  /// Validates, then uploads and saves; rows are rebuilt from what was
  /// saved, so new files now show as the saved ones.
  Future<void> _save() async {
    final Map<String, Map<_PdfField, String>> errors = _validate();
    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
        _expanded.addAll(errors.keys);
      });
      Helper.showSnackBarMessage(
          msg: "Check the highlighted PDF fields", isSuccess: false);
      return;
    }

    setState(() {
      _errors.clear();
      _isSaving = true;
    });
    final List<Topic1Pdf>? saved =
        await widget.onSave([for (final _PdfRow row in _rows) row.toDraft()]);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (saved != null) {
        _resetRows(saved);
        _dirty = false;
      }
    });
  }

  /// Opens the file picker for row [row].
  Future<void> _pick(_PdfRow row) async {
    final PickedPdf? picked = await widget.pickFile();
    if (picked == null || !mounted) return;
    row
      ..newBytes = picked.bytes
      ..newFileName = picked.name;
    _changed();
  }

  /// The last state reported through `onStateChanged`.
  (bool, int)? _reported;

  /// Reports the unsaved state and row count once they change.
  void _reportState() {
    final (bool, int) now = (_dirty, _rows.length);
    if (now == _reported) return;
    _reported = now;
    final void Function(bool, int)? report = widget.onStateChanged;
    if (report == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) report(now.$1, now.$2);
    });
  }

  @override
  Widget build(BuildContext context) {
    _reportState();
    return Topic1SectionCard(
      icon: Icons.picture_as_pdf_outlined,
      title: "PDFs",
      count: _rows.length,
      emptyText: "No PDFs uploaded to this topic.",
      rows: [for (int i = 0; i < _rows.length; i++) _row(i)],
      addLabel: "Add a PDF",
      addKey: const Key('topic1_pdf_add'),
      onAdd: _isSaving
          ? null
          : () {
              final _PdfRow row = _PdfRow.fresh();
              _rows.add(row);
              _expanded.add(row.id);
              _changed();
            },
      saveKey: const Key('topic1_pdf_save'),
      isSaving: _isSaving,
      dirty: _dirty,
      onSave: _save,
    );
  }

  /// The line under a row's title: access, file, and Downloadable if on.
  String _summary(_PdfRow row) {
    final String savedName = (row.existing?.fileName ?? "").trim();
    final String file;
    if (row.newBytes != null) {
      file = "${row.newFileName ?? "New file"} (new)";
    } else if (row.hasFile) {
      file = savedName.isEmpty ? "Uploaded file" : savedName;
    } else {
      file = "No file";
    }
    return [
      topic1AccessLabel(row.type),
      file,
      if (row.isDownloadable) "Downloadable",
    ].join(" · ");
  }

  /// One PDF: a header with its title and summary that folds the rest
  /// away; unfolded, title and access, the file, then Downloadable.
  Widget _row(int index) {
    final _PdfRow row = _rows[index];
    final Map<_PdfField, String> errors = _errors[row.id] ?? const {};
    final bool expanded = _expanded.contains(row.id);

    return Padding(
      key: ValueKey(row.id),
      padding: const EdgeInsets.fromLTRB(18, 8, 12, 8),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Topic1RowHeader(
              index: index,
              title: row.title.text,
              untitledText: "Untitled PDF",
              summary: _summary(row),
              expanded: expanded,
              hasError: errors.isNotEmpty,
              toggleKey: Key('topic1_pdf_toggle_$index'),
              onToggle: () => setState(() {
                if (!_expanded.remove(row.id)) _expanded.add(row.id);
              }),
              removeKey: Key('topic1_pdf_remove_$index'),
              removeTooltip: "Remove this PDF",
              onRemove: _isSaving
                  ? null
                  : () {
                      _rows.removeAt(index).title.dispose();
                      _errors.remove(row.id);
                      _expanded.remove(row.id);
                      _changed();
                    },
            ),
            AnimatedSize(
              duration: topic1FoldDuration,
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: expanded
                  ? _fields(row, index, errors, constraints.maxWidth)
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  /// An unfolded row's fields.
  Widget _fields(
      _PdfRow row, int index, Map<_PdfField, String> errors, double width) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormTwoUp(
            width: width,
            breakpoint: 560,
            left: FormTextField(
              label: "Title",
              hint: "e.g. Kinematics — formula sheet",
              controller: row.title,
              fieldKey: Key('topic1_pdf_title_$index'),
              enabled: !_isSaving,
              error: errors[_PdfField.title],
              onChanged: _changed,
            ),
            right: FormAccessTypeField(
              types: topic1AccessTypes,
              selected: row.type,
              keyPrefix: "topic1_pdf_$index",
              error: errors[_PdfField.type],
              enabled: !_isSaving,
              onSelect: (type) {
                row.type = type;
                _changed();
              },
            ),
          ),
          const SizedBox(height: AppTokens.gapMd),
          _fileField(row, index, errors[_PdfField.file]),
          const SizedBox(height: AppTokens.gapMd),
          FormToggleRow(
            key: Key('topic1_pdf_downloadable_$index'),
            title: "Downloadable",
            subtitle: "Students can save a copy.",
            value: row.isDownloadable,
            onChanged: _isSaving
                ? null
                : (value) {
                    row.isDownloadable = value;
                    _changed();
                  },
          ),
        ],
      ),
    );
  }

  /// The file: what is picked or saved, with Choose / Replace.
  Widget _fileField(_PdfRow row, int index, String? error) {
    final Uint8List? newBytes = row.newBytes;
    final String savedName = (row.existing?.fileName ?? "").trim();

    final String name;
    final String detail;
    if (newBytes != null) {
      name = row.newFileName ?? "New file";
      detail = "${readableFileSize(newBytes.length)} · uploads when you save";
    } else if (row.hasFile) {
      name = savedName.isEmpty ? "Uploaded file" : savedName;
      detail = "Saved";
    } else {
      name = "No file chosen";
      detail = "PDF only";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("File", style: AppTokens.fieldLabel),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            color: row.hasFile ? AppTokens.surface : AppTokens.surfaceMuted,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(
                color: error != null ? AppTokens.danger : AppTokens.hairline),
          ),
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf_outlined,
                  size: 20,
                  color: row.hasFile ? AppTokens.ink : AppTokens.inkFaint),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        key: Key('topic1_pdf_file_name_$index'),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: row.hasFile
                                ? AppTokens.ink
                                : AppTokens.inkFaint)),
                    const SizedBox(height: 2),
                    Text(detail,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppTokens.inkFaint)),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.gapSm),
              OutlinedButton.icon(
                key: Key('topic1_pdf_choose_$index'),
                onPressed: _isSaving ? null : () => _pick(row),
                icon: Icon(row.hasFile ? Icons.swap_horiz : Icons.upload_file,
                    size: 16),
                label: Text(row.hasFile ? "Replace" : "Choose PDF",
                    style: const TextStyle(fontSize: 12.5)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTokens.ink,
                  side: const BorderSide(color: AppTokens.hairline),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
                ),
              ),
            ],
          ),
        ),
        if (error != null) FieldErrorText(error),
      ],
    );
  }
}
