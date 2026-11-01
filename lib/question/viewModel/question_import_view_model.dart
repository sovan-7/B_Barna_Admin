import 'package:bbarna/core/mixins/safe_notifier.dart';
import 'package:bbarna/question/import/question_import_row.dart';
import 'package:bbarna/question/import/question_sheet_parser.dart';
import 'package:bbarna/question/repo/question_repo.dart';
import 'package:flutter/foundation.dart';

/// Where an import stands.
enum ImportStage {
  /// No file chosen yet (or the last one could not be used).
  idle,

  /// Reading the file and checking codes against the collection.
  checking,

  /// Rows are shown; the valid ones can be imported.
  preview,

  /// Writing the valid rows.
  importing,

  /// Finished; [QuestionImportViewModel.importedCount] were written.
  done,
}

/// State for the Import Questions screen: read a sheet, check every row,
/// then write the ready ones in batches.
class QuestionImportViewModel extends ChangeNotifier with SafeNotifier {
  /// Data source. Injectable so tests can pass a mock instead of Firebase.
  final QuestionRepo _questionRepo;
  QuestionImportViewModel({QuestionRepo? questionRepo})
      : _questionRepo = questionRepo ?? QuestionRepo();

  /// Current step.
  ImportStage stage = ImportStage.idle;

  /// Name of the chosen file, for display.
  String? fileName;

  /// Every data row with its problems.
  List<QuestionImportRow> rows = [];

  /// Why the file (not a row) could not be used, or why the import
  /// stopped. Null when nothing went wrong.
  String? error;

  /// Rows written so far (during and after [importValid]).
  int importedCount = 0;

  /// Rows that will be imported.
  List<QuestionImportRow> get validRows => [
        for (final QuestionImportRow row in rows)
          if (row.isValid) row
      ];

  /// Rows that will be skipped.
  int get invalidCount => rows.length - validRows.length;

  /// Whether a long-running step is under way (controls are disabled).
  bool get isBusy =>
      stage == ImportStage.checking || stage == ImportStage.importing;

  /// Reads [bytes] as the file [name], checks every row, and looks up which
  /// codes already exist. Ends in [ImportStage.preview], or back in
  /// [ImportStage.idle] with [error] set.
  Future<void> loadFile(Uint8List bytes, String name) async {
    fileName = name;
    rows = [];
    error = null;
    importedCount = 0;
    stage = ImportStage.checking;
    notifyListeners();

    final List<QuestionImportRow> built;
    try {
      built = buildImportRows(QuestionSheetParser.parse(bytes, name));
    } on QuestionSheetException catch (e) {
      _fail(e.message);
      return;
    }

    final List<String> codes = {
      for (final QuestionImportRow row in built)
        if (row.code.isNotEmpty) row.code,
    }.toList();
    try {
      markExistingCodes(built, await _questionRepo.existingCodes(codes));
    } catch (_) {
      _fail("Couldn't check which codes already exist. "
          "Check your connection and choose the file again.");
      return;
    }

    rows = built;
    stage = ImportStage.preview;
    notifyListeners();
  }

  /// Writes every valid row. On a failure part-way, [importedCount] says
  /// how many made it and [error] says the rest did not.
  Future<void> importValid() async {
    final List<QuestionImportRow> ready = validRows;
    if (stage != ImportStage.preview || ready.isEmpty) return;

    stage = ImportStage.importing;
    importedCount = 0;
    error = null;
    notifyListeners();

    final int timeStamp = DateTime.now().millisecondsSinceEpoch;
    try {
      await _questionRepo.addQuestions(
        [
          // One millisecond apart, so the newest-first list keeps the
          // sheet's order (first row at the bottom, like adding by hand).
          for (int i = 0; i < ready.length; i++)
            ready[i].draft.toMap(timeStamp: timeStamp + i),
        ],
        onProgress: (written) {
          importedCount = written;
          notifyListeners();
        },
      );
    } catch (_) {
      error = importedCount == 0
          ? "Nothing was imported — the save failed. Try again."
          : "Imported $importedCount of ${ready.length}, then the save "
              "failed. Choose the same file again to import the rest — the "
              "ones already saved will be skipped as existing codes.";
    }
    stage = ImportStage.done;
    notifyListeners();
  }

  /// Back to the start, to choose another file.
  void reset() {
    stage = ImportStage.idle;
    fileName = null;
    rows = [];
    error = null;
    importedCount = 0;
    notifyListeners();
  }

  void _fail(String message) {
    error = message;
    rows = [];
    stage = ImportStage.idle;
    notifyListeners();
  }
}
