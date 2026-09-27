import 'package:bbarna/core/widgets/list_page/paged_list_screen.dart';
import 'package:bbarna/question/model/question.dart';
import 'package:bbarna/question/question_viewmodel/question_viewmodel.dart';
import 'package:bbarna/question/screen/add_question.dart';
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
      itemBuilder: (context, question, onChanged) => QuestionCard(
        key: ValueKey(question.docId),
        questionData: question,
        onChanged: onChanged,
      ),
    );
  }
}
