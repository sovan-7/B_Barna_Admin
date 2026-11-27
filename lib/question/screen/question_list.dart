import 'package:bbarna/core/widgets/list_page/paged_list_screen.dart';
import 'package:bbarna/question/model/question.dart';
import 'package:bbarna/question/screen/add_question.dart';
import 'package:bbarna/question/screen/import_questions.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/utils/navigation.dart';
import 'package:bbarna/question/viewModel/question_view_model.dart';
import 'package:bbarna/question/widgets/question_card.dart';
import 'package:bbarna/core/widgets/card/card_chips.dart';
import 'package:bbarna/core/widgets/list_page/admin_table.dart';
import 'package:bbarna/core/widgets/list_page/filter_chips.dart';
import 'package:bbarna/core/widgets/list_page/stats_strip.dart';
import 'package:bbarna/core/widgets/list_page/table_cells.dart';
import 'package:bbarna/documents/media_table.dart';
import 'package:bbarna/question/model/question_draft.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';

/// The question list (sidebar module). All the behaviour lives in
/// [PagedListScreen]; this only supplies the question-specific texts and
/// card.
class QuestionList extends StatelessWidget {
  const QuestionList({super.key});

  @override
  Widget build(BuildContext context) {
    return PagedListScreen<QuestionViewModel, Question>(
      title: "Questions",
      subtitle:
          "Newest first. Questions are attached to quizzes by their code.",
      addButtonLabel: "NEW QUESTION",
      addScreenBuilder: (context) => const AddQuestion(),
      searchHint: "Search by question code",
      skeletonRowHeight: 76,
      emptyIcon: Icons.help_outline,
      emptyTitle: "No questions yet",
      emptyMessage:
          "Questions live here on their own, and quizzes pull them in by code.",
      filteredMessage:
          "No question code starts with that. Search matches the code, not the text.",
      emptyAddLabel: "Add a question",
      extraHeaderAction: (context, viewModel) => _ImportButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ImportQuestions()),
        ).ifSaved(viewModel.refresh),
      ),
      itemBuilder: (context, question, onChanged) => QuestionCard(
        key: ValueKey(question.docId),
        questionData: question,
        onChanged: onChanged,
      ),
      statTiles: (vm) => [
        StatTile.count(
            key: const Key('question_stat_total'),
            label: "Total",
            count: vm.totalCount),
        StatTile.count(
            key: const Key('question_stat_month'),
            label: "Added this month",
            count: vm.stats["month"]),
        StatTile.count(
            key: const Key('question_stat_no_solution'),
            label: "Without a solution",
            count: vm.stats["noSolution"],
            valueColor: (vm.stats["noSolution"] ?? 0) > 0
                ? AppTokens.warningText
                : null),
      ],
      chipOptions: const [
        FilterOption("all", "All", key: Key('question_filter_all')),
        FilterOption("solution", "Has solution",
            key: Key('question_filter_solution')),
        FilterOption("no_solution", "No solution",
            key: Key('question_filter_no_solution')),
      ],
      chipMatches: (question, filter) =>
          _hasText(question.solution) == (filter == "solution"),
      tableColumns: const [
        AdminTableColumn("Question", flex: 6),
        AdminTableColumn("Code", width: 130),
        AdminTableColumn("Answer", width: 72),
        AdminTableColumn("Hint", width: 40, alignment: Alignment.center),
        AdminTableColumn("Solution", width: 60, alignment: Alignment.center),
        AdminTableColumn("Added", width: 96),
        AdminTableColumn("", width: 76, alignment: Alignment.centerRight),
      ],
      rowId: (question) => question.docId,
      rowKeyPrefix: "question",
      tableMinWidth: 820,
      rowCells: (context, question, hovered, onChanged) {
        final QuestionOption? answer = QuestionDraft.answerOf(question);
        final String text = QuestionDraft.plainText(question.question);
        return [
          Text(text.isEmpty ? "No question text" : text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: text.isEmpty ? AppTokens.danger : AppTokens.ink)),
          CodeChip(question.questionCode, copyable: true),
          answer == null
              ? const StatusPill("None", tone: StatusTone.danger)
              : StatusPill(answer.label, tone: StatusTone.success),
          _tick(_hasText(question.hints)),
          _tick(_hasText(question.solution)),
          addedCell(question.timeStamp),
          questionActions(context, question, onChanged, hovered),
        ];
      },
    );
  }
}

/// "IMPORT" beside "NEW QUESTION"; just the icon on narrow windows, where
/// both labels do not fit next to the title.
class _ImportButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _ImportButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final bool narrow = MediaQuery.sizeOf(context).width < 700;
    final ButtonStyle style = OutlinedButton.styleFrom(
      foregroundColor: AppTokens.ink,
      side: const BorderSide(color: AppTokens.hairline),
      padding: EdgeInsets.symmetric(horizontal: narrow ? 10 : 14, vertical: 14),
      minimumSize: Size.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
    );
    const Icon icon = Icon(Icons.upload_file_outlined, size: 17);

    return Tooltip(
      message: "Import questions from a spreadsheet",
      child: narrow
          ? OutlinedButton(
              key: const Key('question_import_button'),
              onPressed: onPressed,
              style: style,
              child: icon,
            )
          : OutlinedButton.icon(
              key: const Key('question_import_button'),
              onPressed: onPressed,
              style: style,
              icon: icon,
              label: const Text("IMPORT",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
    );
  }
}

/// Whether rich [html] has any text once its markup is removed.
bool _hasText(String html) =>
    html != stringDefault && QuestionDraft.plainText(html).isNotEmpty;

/// A green tick when [yes], a faint dash otherwise.
Widget _tick(bool yes) => yes
    ? const Icon(Icons.check_rounded, size: 18, color: AppTokens.successText)
    : const Icon(Icons.remove_rounded, size: 18, color: AppTokens.inkFaint);
