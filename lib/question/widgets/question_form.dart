import 'package:bbarna/core/widgets/form/admin_form_scaffold.dart';
import 'package:bbarna/core/widgets/form/form_action_bar.dart';
import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/question/model/question.dart';
import 'package:bbarna/question/model/question_draft.dart';
import 'package:bbarna/question/viewModel/question_view_model.dart';
import 'package:bbarna/question/widgets/question_rich_field.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/formatters.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:provider/provider.dart';

/// The Add/Edit Question page. One responsive form serves both Add and Edit; the thin screens in
/// `screen/` just choose the mode ([existing] null means Add).
///
/// Sections: the question (code, question, optional body), options A–D
/// with a "correct" toggle each, and hint / solution. Each open form owns
/// its own rich-text editor controllers.
class QuestionForm extends StatefulWidget {
  /// The item being edited; null means "Add".
  final Question? existing;
  const QuestionForm({this.existing, super.key});

  /// True when editing an existing item.
  bool get isEdit => existing != null;

  @override
  State<QuestionForm> createState() => _QuestionFormState();
}

class _QuestionFormState extends State<QuestionForm> {
  /// Text of the code field.
  final TextEditingController codeController = TextEditingController();

  // Editor controllers belong to this form (one set per open form), so two
  // open forms never share text.

  /// Rich-text editor for the question.
  final HtmlEditorController questionController = HtmlEditorController();

  /// Rich-text editor for the optional extra body.
  final HtmlEditorController questionBodyController = HtmlEditorController();

  /// Rich-text editor for option A.
  final HtmlEditorController optionAController = HtmlEditorController();

  /// Rich-text editor for option B.
  final HtmlEditorController optionBController = HtmlEditorController();

  /// Rich-text editor for option C.
  final HtmlEditorController optionCController = HtmlEditorController();

  /// Rich-text editor for option D.
  final HtmlEditorController optionDController = HtmlEditorController();

  /// Rich-text editor for the hint.
  final HtmlEditorController hintController = HtmlEditorController();

  /// Rich-text editor for the solution.
  final HtmlEditorController solutionController = HtmlEditorController();

  /// What the form opens with. For an edit that is the stored question; for
  /// an add it is empty.
  late final QuestionDraft _initial;

  /// Which option is marked correct; null until one is.
  QuestionOption? _answer;

  /// True while saving or deleting; disables every control.
  bool _isSaving = false;

  /// Inline error per field (from [QuestionDraft.validate]).
  Map<QuestionField, String> _errors = {};

  @override
  void initState() {
    super.initState();
    final Question? existing = widget.existing;
    _initial = existing == null
        ? const QuestionDraft()
        : QuestionDraft.fromQuestion(existing);
    codeController.text = _initial.code;
    _answer = _initial.answer;

    // The editors are seeded through `initialText` on each field, not from
    // here: they are webviews that only accept content once their iframe
    // has loaded, well after the first frame.
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  /// The editor holding [option]'s text.
  HtmlEditorController _controllerFor(QuestionOption option) =>
      switch (option) {
        QuestionOption.a => optionAController,
        QuestionOption.b => optionBController,
        QuestionOption.c => optionCController,
        QuestionOption.d => optionDController,
      };

  /// Reads every editor and field into a [QuestionDraft].
  Future<QuestionDraft> _readDraft() async {
    return QuestionDraft(
      code: codeController.text,
      question: await questionController.getText(),
      questionBody: await questionBodyController.getText(),
      optionA: await optionAController.getText(),
      optionB: await optionBController.getText(),
      optionC: await optionCController.getText(),
      optionD: await optionDController.getText(),
      hints: await hintController.getText(),
      solution: await solutionController.getText(),
      answer: _answer,
    );
  }

  /// Validates, then creates or updates the item. Closes the page on
  /// success; on failure the view model has already shown why.
  Future<void> _onSubmit(QuestionViewModel questionViewModel) async {
    final QuestionDraft draft = await _readDraft();
    final Map<QuestionField, String> errors = draft.validate();

    if (errors.isNotEmpty) {
      if (!mounted) return;
      setState(() => _errors = errors);
      Helper.showSnackBarMessage(
          msg: errors.length == 1
              ? "Check the highlighted field"
              : "Check the ${errors.length} highlighted fields",
          isSuccess: false);
      return;
    }

    setState(() {
      _errors = {};
      _isSaving = true;
    });

    final bool success = widget.isEdit
        ? await questionViewModel.updateQuestion(
            widget.existing!.docId,
            draft,
            timeStamp: widget.existing!.timeStamp,
          )
        : await questionViewModel.createQuestion(draft);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Helper.showSnackBarMessage(
          msg: widget.isEdit
              ? "Question updated successfully"
              : "Question added successfully",
          isSuccess: true);
      Navigator.pop(context);
    }
  }

  /// Asks for confirmation, deletes the item and closes the page.
  void _onDelete(QuestionViewModel questionViewModel) {
    final Question existing = widget.existing!;
    RemoveAlert.showRemoveAlert(
      title: existing.questionCode,
      description: "Are you sure want to delete ?",
      onPressYes: () async {
        Navigator.pop(navigatorKey.currentContext!);
        if (mounted) setState(() => _isSaving = true);
        final bool success =
            await questionViewModel.deleteQuestion(existing.docId);
        if (!mounted) return;
        setState(() => _isSaving = false);
        if (success) {
          Helper.showInfoMessage(msg: "Question deleted successfully");
          Navigator.pop(context);
        }
      },
    );
  }

  // ---- Layout ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AdminFormScaffold(
      headerTitle: "Questions",
      sidebarIndex: 9,
      body: (context, width) => Consumer<QuestionViewModel>(
        builder: (context, questionViewModel, child) =>
            _page(questionViewModel, width),
      ),
    );
  }

  /// The scrolling form (header and sections) with the action bar below.
  Widget _page(QuestionViewModel questionViewModel, double width) {
    return FormPageBody(
      width: width,
      maxWidth: 860,
      actionBar: _actionBar(questionViewModel, width),
      children: [
        _pageHeader(),
        const SizedBox(height: AppTokens.gapLg),
        FormSection(title: "THE QUESTION", children: [
          _codeField(),
          const SizedBox(height: AppTokens.gapLg),
          QuestionRichField(
            label: "Question",
            controller: questionController,
            initialText: _initial.question,
            error: _errors[QuestionField.question],
          ),
          const SizedBox(height: AppTokens.gapLg),
          QuestionRichField(
            label: "Passage or diagram",
            hint: "Extra material shown above the question. Optional.",
            controller: questionBodyController,
            initialText: _initial.questionBody,
            height: 160,
          ),
        ]),
        const SizedBox(height: AppTokens.gapMd),
        _optionsSection(),
        const SizedBox(height: AppTokens.gapMd),
        FormSection(title: "AFTER THE ANSWER", children: [
          QuestionRichField(
            label: "Hint",
            hint: "Shown to a student who asks for help. Optional.",
            controller: hintController,
            initialText: _initial.hints,
            height: 150,
          ),
          const SizedBox(height: AppTokens.gapLg),
          QuestionRichField(
            label: "Solution",
            hint: "The worked explanation. Optional.",
            controller: solutionController,
            initialText: _initial.solution,
            height: 200,
          ),
        ]),
        const SizedBox(height: AppTokens.gapXl),
      ],
    );
  }

  /// Question code box (upper-cases as you type).
  Widget _codeField() {
    final String? error = _errors[QuestionField.code];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Question code",
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF344054))),
        const SizedBox(height: 2),
        const Text("Quizzes pull questions in by this code.",
            style: TextStyle(
                fontSize: 11.5, height: 1.35, color: AppTokens.inkFaint)),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Container(
            decoration: BoxDecoration(
              color: AppTokens.surface,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(
                  color: error != null ? AppTokens.danger : AppTokens.hairline),
            ),
            child: TextField(
              controller: codeController,
              inputFormatters: [UpperCaseTextFormatter()],
              style: const TextStyle(fontSize: 13.5, color: AppTokens.ink),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: "e.g. PHY-MECH-001",
                hintStyle: TextStyle(fontSize: 13, color: AppTokens.inkFaint),
                contentPadding: EdgeInsets.fromLTRB(14, 13, 14, 13),
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 5),
          Text(error, style: AppTokens.errorText),
        ],
      ],
    );
  }

  /// The four options, each with a "correct" toggle beside its label, and
  /// the chosen answer summarised in the section heading.
  Widget _optionsSection() {
    final String? answerError = _errors[QuestionField.answer];

    return FormSection(
      title: "OPTIONS",
      trailing: Text(
        _answer == null ? "No answer marked" : "Answer: ${_answer!.label}",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _answer == null ? AppTokens.danger : const Color(0xFF108460),
        ),
      ),
      children: [
        for (final QuestionOption option in QuestionOption.values) ...[
          QuestionRichField(
            label: "Option ${option.label}",
            controller: _controllerFor(option),
            initialText: _initial.optionFor(option),
            error: _errors[option.field],
            height: 130,
            trailing: _correctToggle(option),
          ),
          if (option != QuestionOption.d)
            const SizedBox(height: AppTokens.gapLg),
        ],
        if (answerError != null) ...[
          const SizedBox(height: AppTokens.gapSm),
          Text(answerError, style: AppTokens.errorText),
        ],
      ],
    );
  }

  /// "Correct" toggle beside an option; marking one unmarks the others.
  Widget _correctToggle(QuestionOption option) {
    final bool selected = _answer == option;
    const Color green = Color(0xFF108460);

    return Tooltip(
      message: selected
          ? "Marked as the correct answer"
          : "Mark ${option.label} as the correct answer",
      child: Material(
        color: selected ? green.withValues(alpha: .10) : AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        child: InkWell(
          key: Key('question_correct_${option.label.toLowerCase()}'),
          onTap: _isSaving ? null : () => setState(() => _answer = option),
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              border: Border.all(
                  color: selected
                      ? green.withValues(alpha: .55)
                      : AppTokens.hairline,
                  width: selected ? 1.4 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 14,
                    color: selected ? green : AppTokens.inkFaint),
                const SizedBox(width: 6),
                Text(selected ? "Correct" : "Mark correct",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? green : AppTokens.inkMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Back button, title and subtitle at the top of the page.
  Widget _pageHeader() {
    return FormPageHeader(
      title: widget.isEdit ? "Edit question" : "Add a question",
      subtitle: widget.isEdit
          ? "Update this question, its options and its answer."
          : "Write the question, fill in four options, mark the correct one.",
      onBack: _isSaving ? null : () => Navigator.pop(context),
    );
  }

  /// Delete / Cancel / Save bar pinned to the bottom of the page.
  Widget _actionBar(QuestionViewModel questionViewModel, double width) {
    return FormActionBar(
      width: width,
      isSaving: _isSaving,
      onDelete: widget.isEdit ? () => _onDelete(questionViewModel) : null,
      deleteTooltip: "Delete question",
      saveKey: const Key('question_save_button'),
      saveLabel: widget.isEdit ? "Update question" : "Save question",
      onSave: () => _onSubmit(questionViewModel),
      saveMinWidth: 150,
      maxWidth: 860,
    );
  }
}
