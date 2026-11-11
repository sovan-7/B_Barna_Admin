import 'dart:convert';
import 'dart:typed_data';

import 'package:bbarna/core/widgets/form/admin_form_scaffold.dart';
import 'package:bbarna/core/widgets/form/form_action_bar.dart';
import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/question/import/question_import_row.dart';
import 'package:bbarna/question/import/question_sheet_parser.dart';
import 'package:bbarna/question/viewModel/question_import_view_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Green for "ready" rows and the finished import.
const Color _success = Color(0xFF067647);

/// Import Questions: download the template, choose a .csv / .xlsx file,
/// check every row, then import the ready ones in one go.
///
/// Closes with `true` when anything was imported, so the list reloads.
class ImportQuestions extends StatelessWidget {
  /// Injected in tests; a fresh one per visit otherwise, so every visit
  /// starts from a clean slate.
  final QuestionImportViewModel? viewModel;
  const ImportQuestions({this.viewModel, super.key});

  @override
  Widget build(BuildContext context) {
    final QuestionImportViewModel? injected = viewModel;
    return injected != null
        ? ChangeNotifierProvider.value(
            value: injected, child: const _ImportQuestionsPage())
        : ChangeNotifierProvider(
            create: (_) => QuestionImportViewModel(),
            child: const _ImportQuestionsPage());
  }
}

class _ImportQuestionsPage extends StatelessWidget {
  const _ImportQuestionsPage();

  @override
  Widget build(BuildContext context) {
    return AdminFormScaffold(
      headerTitle: "Questions",
      sidebarIndex: 9,
      body: (context, width) => Consumer<QuestionImportViewModel>(
        builder: (context, vm, child) => PopScope(
          canPop: !vm.isBusy,
          child: FormPageBody(
            width: width,
            maxWidth: 860,
            actionBar: _actionBar(context, vm, width),
            children: [
              FormPageHeader(
                title: "Import questions",
                subtitle: "Add many questions at once from a Word document "
                    "or a spreadsheet.",
                onBack: vm.isBusy ? null : () => _close(context, vm),
              ),
              const SizedBox(height: AppTokens.gapLg),
              _templateSection(vm),
              const SizedBox(height: AppTokens.gapMd),
              _fileSection(context, vm),
              if (vm.rows.isNotEmpty) ...[
                const SizedBox(height: AppTokens.gapMd),
                _rowsSection(vm),
              ],
              const SizedBox(height: AppTokens.gapXl),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Sections -----------------------------------------------------------

  Widget _templateSection(QuestionImportViewModel vm) {
    return FormSection(
      title: "1. PREPARE THE FILE",
      children: [
        const Text("Word document (.docx)", style: AppTokens.fieldLabel),
        const SizedBox(height: AppTokens.gapXs),
        const Text(
          "Each question starts with its code. Options, answer and "
          "explanation follow, each on its own line:",
          style: AppTokens.body,
        ),
        const SizedBox(height: AppTokens.gapSm),
        _docExample(
          key: const Key('import_doc_example'),
          text: "XYZ1. প্রশ্ন লিখুন?\n"
              "(A) প্রথম বিকল্প\n"
              "(B) দ্বিতীয় বিকল্প\n"
              "(C) তৃতীয় বিকল্প\n"
              "(D) চতুর্থ বিকল্প\n"
              "সঠিক উত্তর: (B)\n"
              "ব্যাখ্যা: কেন এটি সঠিক… (optional)",
        ),
        const SizedBox(height: AppTokens.gapMd),
        const Text(
          "Statements or match-the-column lists go after a BODY- line, "
          "before the options. They are saved as the question's passage, "
          "shown under the question:",
          style: AppTokens.body,
        ),
        const SizedBox(height: AppTokens.gapSm),
        _docExample(
          key: const Key('import_doc_body_example'),
          text: "XYZ2 নিচের বিবৃতিগুলি বিচার করো।\n"
              "BODY-\n"
              "A. প্রথম বিবৃতি\n"
              "B. দ্বিতীয় বিবৃতি\n"
              "(A) A-শুদ্ধ, B-অশুদ্ধ\n"
              "(B) A-অশুদ্ধ, B-শুদ্ধ\n"
              "(C) দুটিই শুদ্ধ\n"
              "(D) দুটিই অশুদ্ধ\n"
              "সঠিক উত্তর: (C)",
        ),
        const SizedBox(height: AppTokens.gapSm),
        const Text(
          "The full stop after the code is optional. Answer: / "
          "Explanation: in English work too, as do (ক)–(ঘ) options. Lines "
          "before the first question, like a title, are ignored.",
          style: TextStyle(fontSize: 12.5, color: AppTokens.inkMuted),
        ),
        const SizedBox(height: AppTokens.gapLg),
        const Text("Spreadsheet (.xlsx or .csv)", style: AppTokens.fieldLabel),
        const SizedBox(height: AppTokens.gapXs),
        const Text(
          "One question per row, in Excel or Google Sheets. The first row "
          "names the columns; their order doesn't matter.",
          style: AppTokens.body,
        ),
        const SizedBox(height: AppTokens.gapMd),
        Wrap(
          spacing: AppTokens.gapSm,
          runSpacing: AppTokens.gapSm,
          children: [
            for (final String column in requiredQuestionColumns)
              _columnChip(column, required: true),
            for (final String column in optionalQuestionColumns)
              _columnChip(column, required: false),
          ],
        ),
        const SizedBox(height: AppTokens.gapMd),
        const Text(
          "answer is A, B, C or D (or the exact text of the right option). "
          "Write plain text — formatting such as bold or images can be "
          "added afterwards in Edit question.",
          style: TextStyle(fontSize: 12.5, color: AppTokens.inkMuted),
        ),
        const SizedBox(height: AppTokens.gapMd),
        _outlinedButton(
          key: const Key('import_download_template'),
          icon: Icons.download_outlined,
          label: "Download spreadsheet template",
          onPressed: vm.isBusy
              ? null
              : () => _saveCsv("questions_template.csv", templateCsv()),
        ),
      ],
    );
  }

  Widget _fileSection(BuildContext context, QuestionImportViewModel vm) {
    final String? error = vm.rows.isEmpty ? vm.error : null;
    return FormSection(
      title: "2. CHOOSE THE FILE",
      children: [
        Wrap(
          spacing: AppTokens.gapMd,
          runSpacing: AppTokens.gapSm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _outlinedButton(
              key: const Key('import_choose_file'),
              icon: Icons.upload_file_outlined,
              label: vm.fileName == null
                  ? "Choose .docx, .xlsx or .csv"
                  : "Choose another",
              onPressed: vm.isBusy ? null : () => _pickFile(vm),
            ),
            if (vm.stage == ImportStage.checking)
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: AppTokens.gapSm),
                  Text("Checking rows…", style: AppTokens.body),
                ],
              )
            else if (vm.fileName != null)
              Text(vm.fileName!,
                  overflow: TextOverflow.ellipsis, style: AppTokens.body),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: AppTokens.gapMd),
          Text(error,
              key: const Key('import_file_error'), style: AppTokens.errorText),
        ],
      ],
    );
  }

  Widget _rowsSection(QuestionImportViewModel vm) {
    final int ready = vm.validRows.length;
    return FormSection(
      title: "3. CHECK AND IMPORT",
      children: [
        _summary(vm, ready),
        if (vm.invalidCount > 0) ...[
          const SizedBox(height: AppTokens.gapMd),
          _outlinedButton(
            key: const Key('import_download_rejected'),
            icon: Icons.download_outlined,
            label: "Download rows with problems",
            onPressed: vm.stage == ImportStage.importing
                ? null
                : () =>
                    _saveCsv("questions_to_fix.csv", rejectedRowsCsv(vm.rows)),
          ),
        ],
        const SizedBox(height: AppTokens.gapMd),
        for (final QuestionImportRow row in vm.rows) _rowTile(row),
      ],
    );
  }

  Widget _summary(QuestionImportViewModel vm, int ready) {
    if (vm.stage == ImportStage.importing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Importing ${vm.importedCount} of $ready…",
              style: AppTokens.body),
          const SizedBox(height: AppTokens.gapSm),
          LinearProgressIndicator(
              value: ready == 0 ? null : vm.importedCount / ready),
        ],
      );
    }
    if (vm.stage == ImportStage.done) {
      final String? error = vm.error;
      return Text(
        error ??
            "Imported ${vm.importedCount} questions."
                "${vm.invalidCount > 0 ? " Skipped ${vm.invalidCount}." : ""}",
        key: const Key('import_result'),
        style: error != null
            ? AppTokens.errorText
            : const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: _success),
      );
    }
    return Text.rich(
      key: const Key('import_summary'),
      TextSpan(style: AppTokens.body, children: [
        TextSpan(text: "${vm.rows.length} rows · "),
        TextSpan(text: "$ready ready", style: const TextStyle(color: _success)),
        if (vm.invalidCount > 0)
          TextSpan(
              text: " · ${vm.invalidCount} with problems (will be skipped)",
              style: const TextStyle(color: AppTokens.danger)),
      ]),
    );
  }

  Widget _rowTile(QuestionImportRow row) {
    final bool ok = row.isValid;
    return Container(
      key: Key('import_row_${row.rowNumber}'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTokens.hairline))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ok ? Icons.check_circle_outline : Icons.error_outline,
              size: 18, color: ok ? _success : AppTokens.danger),
          const SizedBox(width: AppTokens.gapSm),
          SizedBox(
            width: 76,
            child: Text(row.label,
                style:
                    const TextStyle(fontSize: 12.5, color: AppTokens.inkMuted)),
          ),
          SizedBox(
            width: 90,
            child: Text(row.code.isEmpty ? "—" : row.code,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.ink)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.preview.isEmpty ? "(no question)" : row.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTokens.body),
                for (final String error in row.errors)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(error, style: AppTokens.errorText),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBar(
      BuildContext context, QuestionImportViewModel vm, double width) {
    final int ready = vm.validRows.length;
    final bool done = vm.stage == ImportStage.done;
    return FormActionBar(
      width: width,
      maxWidth: 860,
      isSaving: vm.isBusy,
      saveKey: const Key('import_save_button'),
      saveMinWidth: 180,
      saveLabel: done
          ? "Done"
          : ready == 1
              ? "Import 1 question"
              : "Import $ready questions",
      onSave: () {
        if (done) {
          _close(context, vm);
        } else if (vm.stage != ImportStage.preview) {
          Helper.showSnackBarMessage(
              msg: "Choose a file first", isSuccess: false);
        } else if (ready == 0) {
          Helper.showSnackBarMessage(
              msg: "No rows are ready — fix the file and choose it again",
              isSuccess: false);
        } else {
          vm.importValid();
        }
      },
    );
  }

  // ---- Pieces -------------------------------------------------------------

  /// A Word layout example, as the admin would type it.
  Widget _docExample({required Key key, required String text}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: AppTokens.hairline),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12.5, height: 1.5, color: AppTokens.ink)),
    );
  }

  Widget _columnChip(String column, {required bool required}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: required ? AppTokens.surfaceMuted : AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: AppTokens.hairline),
      ),
      child: Text(required ? column : "$column (optional)",
          style: TextStyle(
              fontSize: 12,
              fontFamily: "monospace",
              color: required ? AppTokens.ink : AppTokens.inkMuted)),
    );
  }

  Widget _outlinedButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      key: key,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTokens.ink,
        side: const BorderSide(color: AppTokens.hairline),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
      ),
      icon: Icon(icon, size: 17),
      label: Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  // ---- Actions ------------------------------------------------------------

  Future<void> _pickFile(QuestionImportViewModel vm) async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['docx', 'xlsx', 'csv'],
      withData: true,
    );
    final PlatformFile? file = picked?.files.firstOrNull;
    final Uint8List? bytes = file?.bytes;
    if (file == null) return;
    if (bytes == null) {
      Helper.showSnackBarMessage(
          msg: "Couldn't read that file", isSuccess: false);
      return;
    }
    await vm.loadFile(bytes, file.name);
  }

  /// Hands [csv] to the browser / OS as a file called [name].
  Future<void> _saveCsv(String name, String csv) async {
    try {
      await FilePicker.platform.saveFile(
        dialogTitle: "Save $name",
        fileName: name,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        // With a byte-order mark Excel opens it as UTF-8, so non-English
        // text survives.
        bytes: Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]),
      );
    } catch (_) {
      Helper.showSnackBarMessage(
          msg: "Couldn't save the file", isSuccess: false);
    }
  }

  /// Leaves the screen; `true` when something was imported.
  void _close(BuildContext context, QuestionImportViewModel vm) {
    Navigator.pop(context, vm.importedCount > 0);
  }
}
