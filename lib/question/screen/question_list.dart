import 'package:bbarna/core/widgets/list_page/paged_list_screen.dart';
import 'package:bbarna/question/model/question.dart';
import 'package:bbarna/question/screen/add_question.dart';
import 'package:bbarna/question/screen/import_questions.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/utils/navigation.dart';
import 'package:bbarna/question/viewModel/question_view_model.dart';
import 'package:bbarna/question/widgets/question_card.dart';
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
