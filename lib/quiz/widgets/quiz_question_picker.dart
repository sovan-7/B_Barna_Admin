import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/question/model/question.dart';
import 'package:bbarna/quiz/viewModel/quiz_view_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;

/// "QUESTIONS" section of the Add/Edit Quiz form.
///
/// Attached questions are listed at the top (the count in the heading is
/// what gets saved); below, a search by question code finds more to add.
/// Adding moves a question from the results onto the quiz; the view model
/// holds both lists.
class QuizQuestionPicker extends StatefulWidget {
  /// Holds the attached questions and the search results.
  final QuizViewModel quizViewModel;

  /// Text of the question-code search box (owned by the form).
  final TextEditingController searchController;

  /// False while the quiz is saving: nothing can be added or removed.
  final bool enabled;

  const QuizQuestionPicker({
    required this.quizViewModel,
    required this.searchController,
    required this.enabled,
    super.key,
  });

  @override
  State<QuizQuestionPicker> createState() => _QuizQuestionPickerState();
}

class _QuizQuestionPickerState extends State<QuizQuestionPicker> {
  @override
  @override
  Widget build(BuildContext context) {
    final List<Question> attached = widget.quizViewModel.quizQuestionList;

    return FormSection(
      title: "QUESTIONS",
      trailing: Text(
        "${attached.length} attached",
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: AppTokens.ink),
      ),
      children: [
        if (widget.quizViewModel.isLoadingQuestions)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: AppTokens.inkFaint),
              ),
            ),
          )
        else if (attached.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTokens.surfaceMuted,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(color: AppTokens.hairline),
            ),
            child: const Column(
              children: [
                Icon(Icons.help_outline, size: 22, color: AppTokens.inkFaint),
                SizedBox(height: 8),
                Text("No questions attached yet",
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTokens.ink)),
                SizedBox(height: 3),
                Text("Search by question code below to add some.",
                    style:
                        TextStyle(fontSize: 11.5, color: AppTokens.inkFaint)),
              ],
            ),
          )
        else
          for (int i = 0; i < attached.length; i++)
            _questionRow(
              question: attached[i],
              index: i + 1,
              attached: true,
              onTap: () => widget.quizViewModel.removeQuestion(attached[i]),
            ),
        const SizedBox(height: AppTokens.gapLg),
        const Divider(height: 1, thickness: 1, color: AppTokens.hairline),
        const SizedBox(height: AppTokens.gapLg),
        _search(),
      ],
    );
  }

  /// "Add questions": code search, the results with "Add all", or a note
  /// when nothing new matched.
  Widget _search() {
    final List<Question> found = widget.quizViewModel.questionList;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Add questions", style: AppTokens.fieldLabel),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTokens.surface,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  border: Border.all(color: AppTokens.hairline),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search,
                        size: 17, color: AppTokens.inkFaint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        key: const Key('quiz_question_search'),
                        controller: widget.searchController,
                        style:
                            const TextStyle(fontSize: 13, color: AppTokens.ink),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: "Search by question code",
                          hintStyle: TextStyle(
                              fontSize: 13, color: AppTokens.inkFaint),
                        ),
                        onSubmitted: (value) =>
                            widget.quizViewModel.searchQuestions(value),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppTokens.gapSm),
            OutlinedButton(
              key: const Key('quiz_question_search_button'),
              onPressed: !widget.enabled
                  ? null
                  : () => widget.quizViewModel
                      .searchQuestions(widget.searchController.text),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTokens.ink,
                side: const BorderSide(color: AppTokens.hairline),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
              ),
              child: const Text("Search", style: TextStyle(fontSize: 12.5)),
            ),
          ],
        ),
        if (found.isNotEmpty) ...[
          const SizedBox(height: AppTokens.gapMd),
          Row(
            children: [
              Text("${found.length} found",
                  style:
                      const TextStyle(fontSize: 12, color: AppTokens.inkMuted)),
              const Spacer(),
              TextButton.icon(
                key: const Key('quiz_add_all_questions'),
                onPressed: !widget.enabled
                    ? null
                    : widget.quizViewModel.addAllFoundQuestions,
                icon: const Icon(Icons.playlist_add, size: 16),
                label: const Text("Add all", style: TextStyle(fontSize: 12.5)),
                style: TextButton.styleFrom(
                    foregroundColor: AppTokens.inkMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 10)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final Question question in found)
            _questionRow(
              question: question,
              attached: false,
              onTap: () => widget.quizViewModel.addQuestion(question),
            ),
        ] else if (widget.searchController.text.trim().isNotEmpty &&
            !widget.quizViewModel.isLoadingQuestions) ...[
          const SizedBox(height: AppTokens.gapMd),
          const Text(
            "Nothing new for that code — questions already on the quiz are "
            "hidden from these results.",
            style: TextStyle(fontSize: 11.5, color: AppTokens.inkFaint),
          ),
        ],
      ],
    );
  }

  /// One question: code, plain-text body, and an add (+) or remove (×)
  /// button.
  Widget _questionRow({
    required Question question,
    required bool attached,
    required VoidCallback onTap,
    int? index,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: attached ? AppTokens.surface : AppTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: AppTokens.hairline),
      ),
      child: Row(
        children: [
          if (index != null) ...[
            SizedBox(
              width: 22,
              child: Text("$index",
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.inkFaint)),
            ),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.questionCode,
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: AppTokens.inkMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  // Questions are stored as HTML; show plain text so each
                  // row stays one or two lines tall.
                  _plainText(question.question),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5, height: 1.35, color: AppTokens.ink),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.gapSm),
          Tooltip(
            message: attached ? "Remove from the quiz" : "Add to the quiz",
            child: InkWell(
              key: Key(
                  '${attached ? 'quiz_remove' : 'quiz_add'}_${question.questionCode}'),
              onTap: !widget.enabled ? null : onTap,
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  attached ? Icons.close : Icons.add,
                  size: 17,
                  color: attached ? AppTokens.danger : const Color(0xFF108460),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The question body with its HTML stripped ("Untitled question" when
  /// empty).
  static String _plainText(String html) {
    if (html.trim().isEmpty || html == stringDefault) {
      return "Untitled question";
    }
    final String text =
        html_parser.parse(html).body?.text.trim() ?? html.trim();
    return text.isEmpty ? "Untitled question" : text;
  }
}
