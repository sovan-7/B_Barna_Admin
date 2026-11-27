import 'package:bbarna/core/widgets/list_page/paged_list_screen.dart';
import 'package:bbarna/quiz/model/quiz_model.dart';
import 'package:bbarna/quiz/screen/add_quiz.dart';
import 'package:bbarna/quiz/viewModel/quiz_view_model.dart';
import 'package:bbarna/quiz/widgets/quiz_card.dart';
import 'package:bbarna/core/widgets/list_page/admin_table.dart';
import 'package:bbarna/core/widgets/list_page/filter_chips.dart';
import 'package:bbarna/core/widgets/list_page/stats_strip.dart';
import 'package:bbarna/core/widgets/list_page/table_cells.dart';
import 'package:bbarna/core/widgets/list_page/table_identity.dart';
import 'package:bbarna/documents/media_table.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

/// The quiz list (sidebar module). All the behaviour lives in
/// [PagedListScreen]; this only supplies the quiz-specific texts and card.
class QuizList extends StatelessWidget {
  const QuizList({super.key});

  @override
  Widget build(BuildContext context) {
    return PagedListScreen<QuizViewModel, QuizModel>(
      title: "Quizzes",
      subtitle: "Newest first. Live quizzes are open to students now.",
      addButtonLabel: "NEW QUIZ",
      addScreenBuilder: (context) => const AddQuiz(),
      searchHint: "Search by quiz code",
      skeletonRowHeight: 82,
      emptyIcon: Icons.quiz_outlined,
      emptyTitle: "No quizzes yet",
      emptyMessage:
          "A quiz is a set of questions with a time limit and a mark scheme.",
      filteredMessage:
          "No quiz code starts with that. Search matches the code, not the name.",
      emptyAddLabel: "Add a quiz",
      itemBuilder: (context, quiz, onChanged) => QuizCard(
        key: ValueKey(quiz.docId),
        quizData: quiz,
        onChanged: onChanged,
      ),
      statTiles: (vm) => [
        StatTile.count(
            key: const Key('quiz_stat_total'),
            label: "Total",
            count: vm.totalCount),
        StatTile.count(
            key: const Key('quiz_stat_live'),
            label: "Live",
            count: vm.stats["live"],
            valueColor: AppTokens.dangerText),
        StatTile.count(
            key: const Key('quiz_stat_upcoming'),
            label: "Upcoming",
            count: vm.stats["upcoming"],
            valueColor: AppTokens.infoText),
        StatTile.count(
            key: const Key('quiz_stat_pending'),
            label: "Pending",
            count: vm.stats["pending"]),
      ],
      chipOptions: const [
        FilterOption("all", "All", key: Key('quiz_filter_all')),
        FilterOption("live", "Live", key: Key('quiz_filter_live')),
        FilterOption("upcoming", "Upcoming", key: Key('quiz_filter_upcoming')),
        FilterOption("pending", "Pending", key: Key('quiz_filter_pending')),
        FilterOption("free", "Free", key: Key('quiz_filter_free')),
        FilterOption("paid", "Paid", key: Key('quiz_filter_paid')),
      ],
      chipMatches: quizChipMatches,
      tableColumns: const [
        AdminTableColumn("Quiz", flex: 5),
        AdminTableColumn("Questions", width: 78),
        AdminTableColumn("Time", width: 70),
        AdminTableColumn("Marking", width: 78),
        AdminTableColumn("Access", width: 84),
        AdminTableColumn("Status", width: 150),
        AdminTableColumn("", width: 108, alignment: Alignment.centerRight),
      ],
      rowId: (quiz) => quiz.docId,
      rowKeyPrefix: "quiz",
      tableMinWidth: 900,
      rowCells: (context, quiz, hovered, onChanged) => [
        TableIdentity(
            title: quiz.name,
            subtitle: quiz.code,
            icon: Icons.quiz_outlined,
            iconColor: AppTokens.accent),
        TableText("${quiz.questionCodeList.length}"),
        TableText(formatDuration(quiz.totalTime)),
        TableText(quiz.totalMarks > 0
            ? "+${quiz.totalMarks} / −${quiz.numberDeduction}"
            : null),
        accessPill(quiz.type),
        quizStatusPill(quiz),
        quizActions(context, quiz, onChanged, hovered),
      ],
    );
  }
}

/// Whether [quiz] shows under chip [filter]: a status as students see it
/// (an opened upcoming quiz is live), or free / paid.
bool quizChipMatches(QuizModel quiz, String filter) {
  switch (filter) {
    case "free":
    case "paid":
      return accessChipMatches(quiz.type, filter);
    default:
      return quiz.effectiveStatus.toLowerCase() == filter;
  }
}

/// Live (red dot), Upcoming with its opening time, or Pending.
Widget quizStatusPill(QuizModel quiz, {DateTime? now}) {
  final String status = quiz.statusAt(now ?? DateTime.now()).toUpperCase();
  if (status == QuizModel.statusLive) {
    return const StatusPill("Live", tone: StatusTone.danger, dot: true);
  }
  if (status == QuizModel.statusUpcoming) {
    final DateTime? opensAt = quiz.availableAt;
    return StatusPill(
        opensAt == null
            ? "Upcoming"
            : "Opens ${DateFormat('d MMM, HH:mm').format(opensAt)}",
        tone: StatusTone.info,
        icon: Icons.schedule);
  }
  if (status.isEmpty || status == stringDefault.toUpperCase()) {
    return const StatusPill("No status");
  }
  return const StatusPill("Pending");
}
