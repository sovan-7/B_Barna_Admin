import 'package:bbarna/core/widgets/form/admin_form_scaffold.dart';
import 'package:bbarna/core/widgets/form/form_action_bar.dart';
import 'package:bbarna/core/widgets/form/form_fields.dart';
import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/question/model/question.dart';
import 'package:bbarna/quiz/model/quiz_model.dart';
import 'package:bbarna/quiz/viewModel/quiz_view_model.dart';
import 'package:bbarna/quiz/widgets/quiz_card.dart'
    show formatDuration, statusColor, statusIcon;
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/formatters.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:provider/provider.dart';

/// The whole Add/Edit Quiz page. [existing] null means Add.
///
/// Add and Edit were two 518 and 934 line screens, and only Edit could
/// attach questions at all — Add hardcoded an empty list, so every new quiz
/// had to be saved and reopened before it could be given any. There is one
/// responsive form here and it picks questions in both modes.
class QuizForm extends StatefulWidget {
  final QuizModel? existing;
  const QuizForm({this.existing, super.key});

  bool get isEdit => existing != null;

  @override
  State<QuizForm> createState() => _QuizFormState();
}

enum _Field { code, name, status, type, time, marks }

class _QuizFormState extends State<QuizForm> {
  final TextEditingController codeController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController hoursController = TextEditingController();
  final TextEditingController minutesController = TextEditingController();
  final TextEditingController marksController = TextEditingController();
  final TextEditingController deductionController = TextEditingController();
  final TextEditingController questionSearchController =
      TextEditingController();

  static const List<String> statusList = ["UPCOMING", "LIVE", "PENDING"];
  static const List<String> typeList = ["FREE", "PAID"];

  String? _selectedStatus;
  String? _selectedType;
  bool _isSaving = false;

  final Map<_Field, String> _errors = <_Field, String>{};

  @override
  void initState() {
    super.initState();
    final QuizModel? existing = widget.existing;
    if (existing != null) {
      codeController.text = existing.code;
      nameController.text = existing.name;
      if (existing.totalTime > 0) {
        hoursController.text = (existing.totalTime ~/ 60).toString();
        minutesController.text = (existing.totalTime % 60).toString();
      }
      if (existing.totalMarks > 0) {
        marksController.text = existing.totalMarks.toString();
      }
      if (existing.numberDeduction > 0) {
        deductionController.text = existing.numberDeduction.toString();
      }
      _selectedStatus =
          statusList.contains(existing.status) ? existing.status : null;
      _selectedType = typeList.contains(existing.type) ? existing.type : null;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final QuizViewModel quizViewModel =
          Provider.of<QuizViewModel>(context, listen: false);
      quizViewModel.clearQuestionPicker();
      quizViewModel.loadQuizQuestions(existing?.questionCodeList ?? const []);
    });
  }

  @override
  void dispose() {
    codeController.dispose();
    nameController.dispose();
    hoursController.dispose();
    minutesController.dispose();
    marksController.dispose();
    deductionController.dispose();
    questionSearchController.dispose();
    super.dispose();
  }

  int get _totalMinutes {
    final int hours = int.tryParse(hoursController.text.trim()) ?? 0;
    final int minutes = int.tryParse(minutesController.text.trim()) ?? 0;
    return (hours * 60) + minutes;
  }

  Map<_Field, String> _validate() {
    final Map<_Field, String> errors = <_Field, String>{};
    if (codeController.text.trim().isEmpty) {
      errors[_Field.code] = "Give the quiz a code";
    }
    if (nameController.text.trim().isEmpty) {
      errors[_Field.name] = "Give the quiz a name";
    }
    if ((_selectedStatus ?? "").isEmpty) {
      errors[_Field.status] = "Choose a status";
    }
    if ((_selectedType ?? "").isEmpty) {
      errors[_Field.type] = "Choose whether it is free or paid";
    }
    if (_totalMinutes <= 0) {
      errors[_Field.time] = "Set how long the quiz runs";
    }
    final String marks = marksController.text.trim();
    if (marks.isEmpty) {
      errors[_Field.marks] = "Set the total marks";
    } else if ((int.tryParse(marks) ?? 0) <= 0) {
      errors[_Field.marks] = "Total marks must be more than zero";
    }
    return errors;
  }

  void _revalidate() {
    if (_errors.isEmpty) return;
    final Map<_Field, String> fresh = _validate();
    setState(() {
      _errors
        ..clear()
        ..addAll(fresh);
    });
  }

  Future<void> _onSubmit(QuizViewModel quizViewModel) async {
    final Map<_Field, String> errors = _validate();
    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
      });
      Helper.showSnackBarMessage(
          msg: errors.length == 1
              ? "Check the highlighted field"
              : "Check the ${errors.length} highlighted fields",
          isSuccess: false);
      return;
    }

    setState(() {
      _errors.clear();
      _isSaving = true;
    });

    final List<String> questionCodes = quizViewModel.selectedQuestionCodeList;

    final QuizModel model = QuizModel(
      codeController.text.trim().toUpperCase(),
      nameController.text.trim(),
      _selectedStatus ?? stringDefault,
      _selectedType ?? stringDefault,
      _totalMinutes,
      widget.existing?.timeStamp ?? DateTime.now().millisecondsSinceEpoch,
      int.parse(marksController.text.trim()),
      int.tryParse(deductionController.text.trim()) ?? 0,
      widget.existing?.totalWrongAnswer ?? 0,
      // The question count is derived from the questions actually attached.
      // It used to be a number typed by hand in its own field, with nothing
      // keeping the two in step.
      questionCodes.length,
      questionCodes,
    );

    final bool success = widget.isEdit
        ? await quizViewModel.updateQuiz(model, widget.existing!.docId)
        : await quizViewModel.addQuiz(model);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Helper.showSnackBarMessage(
          msg: widget.isEdit
              ? "Quiz updated successfully"
              : "Quiz added successfully",
          isSuccess: true);
      Navigator.pop(context);
    }
  }

  void _onDelete(QuizViewModel quizViewModel) {
    final QuizModel existing = widget.existing!;
    RemoveAlert.showRemoveAlert(
      title: existing.name,
      description: "Are you sure want to delete ?",
      onPressYes: () async {
        Navigator.pop(navigatorKey.currentContext!);
        if (mounted) setState(() => _isSaving = true);
        final bool success = await quizViewModel.deleteQuiz(existing.docId);
        if (!mounted) return;
        setState(() => _isSaving = false);
        if (success) {
          Helper.showInfoMessage(msg: "Quiz deleted successfully");
          Navigator.pop(context);
        }
      },
    );
  }

  // ---- Layout ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AdminFormScaffold(
      headerTitle: "Quizzes",
      sidebarIndex: 8,
      body: (context, width) => Consumer<QuizViewModel>(
        builder: (context, quizViewModel, child) => _page(quizViewModel, width),
      ),
    );
  }

  Widget _page(QuizViewModel quizViewModel, double width) {
    return FormPageBody(
      width: width,
      maxWidth: 760,
      actionBar: _actionBar(quizViewModel, width),
      children: [
        _pageHeader(),
        const SizedBox(height: AppTokens.gapLg),
        FormSection(title: "QUIZ DETAILS", children: [
          FormTwoUp(
              width: width,
              left: _textField(
                label: "Quiz code",
                hint: "e.g. MOCK-01",
                controller: codeController,
                error: _errors[_Field.code],
                onChanged: _revalidate,
                uppercase: true,
              ),
              right: _textField(
                label: "Quiz name",
                hint: "e.g. Physics mock test 1",
                controller: nameController,
                error: _errors[_Field.name],
                onChanged: _revalidate,
              )),
          const SizedBox(height: AppTokens.gapMd),
          _statusField(),
          const SizedBox(height: AppTokens.gapMd),
          _typeField(),
        ]),
        const SizedBox(height: AppTokens.gapMd),
        FormSection(title: "RULES", children: [
          _durationField(),
          const SizedBox(height: AppTokens.gapMd),
          FormTwoUp(
              width: width,
              left: _textField(
                label: "Total marks",
                hint: "e.g. 100",
                controller: marksController,
                error: _errors[_Field.marks],
                onChanged: _revalidate,
                numeric: true,
              ),
              right: _textField(
                label: "Negative marking",
                hint: "Marks lost per wrong answer (optional)",
                controller: deductionController,
                numeric: true,
              )),
        ]),
        const SizedBox(height: AppTokens.gapMd),
        _questionSection(quizViewModel),
        const SizedBox(height: AppTokens.gapXl),
      ],
    );
  }

  /// Back button, title and subtitle at the top of the page.
  Widget _pageHeader() {
    return FormPageHeader(
      title: widget.isEdit ? "Edit quiz" : "Add a quiz",
      subtitle: widget.isEdit
          ? "Update this quiz's rules and its questions."
          : "Set the rules, then attach the questions.",
      onBack: _isSaving ? null : () => Navigator.pop(context),
    );
  }

  /// A [FormTextField] configured for this form.
  Widget _textField({
    required String label,
    required String hint,
    required TextEditingController controller,
    String? error,
    VoidCallback? onChanged,
    bool numeric = false,
    bool uppercase = false,
  }) {
    return FormTextField(
      label: label,
      hint: hint,
      controller: controller,
      error: error,
      onChanged: onChanged,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters: [
        if (numeric) FilteringTextInputFormatter.digitsOnly,
        if (uppercase) UpperCaseTextFormatter(),
      ],
    );
  }

  /// Hours and minutes side by side with the total spelled out underneath.
  /// The two boxes were unlabelled before, and nothing said they were
  /// summed into one number of minutes.
  Widget _durationField() {
    final String? error = _errors[_Field.time];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Time limit", style: AppTokens.fieldLabel),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
                child: _numberBox(hoursController, "Hours", error != null)),
            const SizedBox(width: AppTokens.gapSm),
            Expanded(
                child: _numberBox(minutesController, "Minutes", error != null)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _totalMinutes > 0
              ? "Students get ${formatDuration(_totalMinutes)}."
              : "Enter hours, minutes, or both.",
          style: const TextStyle(fontSize: 11.5, color: AppTokens.inkFaint),
        ),
        if (error != null) ...[
          const SizedBox(height: 5),
          Text(error, style: AppTokens.errorText),
        ],
      ],
    );
  }

  Widget _numberBox(
      TextEditingController controller, String suffix, bool hasError) {
    return Container(
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border:
            Border.all(color: hasError ? AppTokens.danger : AppTokens.hairline),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) {
          setState(() {});
          _revalidate();
        },
        style: const TextStyle(fontSize: 13.5, color: AppTokens.ink),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: "0",
          hintStyle: const TextStyle(fontSize: 13, color: AppTokens.inkFaint),
          suffixText: suffix,
          suffixStyle: const TextStyle(fontSize: 12, color: AppTokens.inkFaint),
          contentPadding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        ),
      ),
    );
  }

  Widget _statusField() {
    final String? error = _errors[_Field.status];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Status", style: AppTokens.fieldLabel),
        const SizedBox(height: 6),
        Wrap(
          spacing: AppTokens.gapSm,
          runSpacing: AppTokens.gapSm,
          children: [
            for (final String status in statusList)
              _choiceChip(
                key: Key('quiz_status_${status.toLowerCase()}'),
                label: status,
                icon: statusIcon(status),
                color: statusColor(status),
                selected: _selectedStatus == status,
                onTap: () {
                  setState(() => _selectedStatus = status);
                  _revalidate();
                },
              ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 5),
          Text(error, style: AppTokens.errorText),
        ],
      ],
    );
  }

  Widget _typeField() {
    final String? error = _errors[_Field.type];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Access", style: AppTokens.fieldLabel),
        const SizedBox(height: 6),
        Wrap(
          spacing: AppTokens.gapSm,
          children: [
            for (final String type in typeList)
              _choiceChip(
                key: Key('quiz_type_${type.toLowerCase()}'),
                label: type,
                icon: type == "FREE"
                    ? Icons.lock_open_outlined
                    : Icons.paid_outlined,
                color: type == "FREE"
                    ? const Color(0xFF108460)
                    : const Color(0xFFB54708),
                selected: _selectedType == type,
                onTap: () {
                  setState(() => _selectedType = type);
                  _revalidate();
                },
              ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 5),
          Text(error, style: AppTokens.errorText),
        ],
      ],
    );
  }

  /// Status was three coloured boxes you tapped with no selected state to
  /// speak of. These read as a choice, and the selected one is obvious.
  Widget _choiceChip({
    required Key key,
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? color.withValues(alpha: .10) : AppTokens.surface,
      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      child: InkWell(
        key: key,
        onTap: _isSaving ? null : onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            border: Border.all(
                color: selected
                    ? color.withValues(alpha: .55)
                    : AppTokens.hairline,
                width: selected ? 1.4 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14, color: selected ? color : AppTokens.inkFaint),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0.3,
                      color: selected ? color : AppTokens.inkMuted)),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Questions -------------------------------------------------------

  /// Attached questions above, a search to add more below.
  ///
  /// The old picker kept found and attached questions in two lists that
  /// both carried an `isSelected` flag, so what was actually on the quiz
  /// had to be reconstructed from two half-selected lists at save time.
  /// Adding moves a question between the lists here, and the count in the
  /// heading is the count that gets saved.
  Widget _questionSection(QuizViewModel quizViewModel) {
    final List<Question> attached = quizViewModel.quizQuestionList;

    return FormSection(
      title: "QUESTIONS",
      trailing: Text(
        "${attached.length} attached",
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: AppTokens.ink),
      ),
      children: [
        if (quizViewModel.isLoadingQuestions)
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
              onTap: () => quizViewModel.removeQuestion(attached[i]),
            ),
        const SizedBox(height: AppTokens.gapLg),
        const Divider(height: 1, thickness: 1, color: AppTokens.hairline),
        const SizedBox(height: AppTokens.gapLg),
        _questionSearch(quizViewModel),
      ],
    );
  }

  Widget _questionSearch(QuizViewModel quizViewModel) {
    final List<Question> found = quizViewModel.questionList;

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
                        controller: questionSearchController,
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
                            quizViewModel.searchQuestions(value),
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
              onPressed: _isSaving
                  ? null
                  : () => quizViewModel
                      .searchQuestions(questionSearchController.text),
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
                onPressed:
                    _isSaving ? null : quizViewModel.addAllFoundQuestions,
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
              onTap: () => quizViewModel.addQuestion(question),
            ),
        ] else if (questionSearchController.text.trim().isNotEmpty &&
            !quizViewModel.isLoadingQuestions) ...[
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
                  // Questions are stored as HTML; the old picker rendered
                  // the markup in the row itself, which made a one-line
                  // list item as tall as the question's formatting.
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
              onTap: _isSaving ? null : onTap,
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

  static String _plainText(String html) {
    if (html.trim().isEmpty || html == stringDefault) {
      return "Untitled question";
    }
    final String text =
        html_parser.parse(html).body?.text.trim() ?? html.trim();
    return text.isEmpty ? "Untitled question" : text;
  }

  /// Delete / Cancel / Save bar pinned to the bottom of the page.
  Widget _actionBar(QuizViewModel quizViewModel, double width) {
    return FormActionBar(
      width: width,
      isSaving: _isSaving,
      onDelete: widget.isEdit ? () => _onDelete(quizViewModel) : null,
      deleteTooltip: "Delete quiz",
      saveKey: const Key('quiz_save_button'),
      saveLabel: widget.isEdit ? "Update quiz" : "Save quiz",
      onSave: () => _onSubmit(quizViewModel),
      saveMinWidth: 130,
      maxWidth: 760,
    );
  }
}
