import 'package:bbarna/core/widgets/list_page/paged_list_screen.dart';
import 'package:bbarna/quiz/model/quiz_model.dart';
import 'package:bbarna/quiz/screen/add_quiz.dart';
import 'package:bbarna/quiz/viewModel/quiz_view_model.dart';
import 'package:bbarna/quiz/widgets/quiz_card.dart';
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
    );
  }
}
