import 'package:bbarna/core/widgets/form/admin_form_scaffold.dart';
import 'package:bbarna/core/widgets/form/form_action_bar.dart';
import 'package:bbarna/core/widgets/form/form_fields.dart';
import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/quiz/model/quiz_model.dart';
import 'package:bbarna/quiz/viewModel/quiz_view_model.dart';
import 'package:bbarna/quiz/widgets/quiz_card.dart'
    show formatDuration, statusColor, statusIcon;
import 'package:bbarna/quiz/widgets/quiz_question_picker.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/formatters.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// The Add/Edit Quiz page. One responsive form serves both Add and Edit; the thin screens in
/// `screen/` just choose the mode ([existing] null means Add).
///
/// Sections: details (code, name), rules (time limit, marks, negative
/// marking, status, free/paid) and the question picker, which works in
/// both modes.
class QuizForm extends StatefulWidget {
  /// The item being edited; null means "Add".
  final QuizModel? existing;
  const QuizForm({this.existing, super.key});

  /// True when editing an existing item.
  bool get isEdit => existing != null;

  @override
  State<QuizForm> createState() => _QuizFormState();
}

/// The fields that can carry an inline error.
enum _Field { code, name, status, type, time, marks }

class _QuizFormState extends State<QuizForm> {
  /// Text of the code field.
  final TextEditingController codeController = TextEditingController();

  /// Text of the name field.
  final TextEditingController nameController = TextEditingController();

  /// Text of the hours part of the time limit field.
  final TextEditingController hoursController = TextEditingController();

  /// Text of the minutes part of the time limit field.
  final TextEditingController minutesController = TextEditingController();

  /// Text of the total marks field.
  final TextEditingController marksController = TextEditingController();

  /// Text of the negative marking field.
  final TextEditingController deductionController = TextEditingController();

  /// Text of the question-code search field.
  final TextEditingController questionSearchController =
      TextEditingController();

  /// Quiz status options.
  static const List<String> statusList = ["UPCOMING", "LIVE", "PENDING"];

  /// Access types offered.
  static const List<String> typeList = ["FREE", "PAID"];

  /// The chosen status.
  String? _selectedStatus;

  /// The chosen access type ("FREE" / "PAID").
  String? _selectedType;

  /// True while saving or deleting; disables every control.
  bool _isSaving = false;

  /// Inline error per field: filled on a failed submit, then refreshed on
  /// every change so each message clears as its field is fixed.
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

  /// Hours and minutes fields combined, in minutes.
  int get _totalMinutes {
    final int hours = int.tryParse(hoursController.text.trim()) ?? 0;
    final int minutes = int.tryParse(minutesController.text.trim()) ?? 0;
    return (hours * 60) + minutes;
  }

  /// Checks every field and returns the problems (empty when valid).
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

  /// Re-runs validation after an edit, but only once a submit has failed
  /// (so errors never appear while the form is still being filled in).
  void _revalidate() {
    if (_errors.isEmpty) return;
    final Map<_Field, String> fresh = _validate();
    setState(() {
      _errors
        ..clear()
        ..addAll(fresh);
    });
  }

  /// Validates, then creates or updates the item. Closes the page on
  /// success; on failure the view model has already shown why.
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
      // The question count is always the number of questions attached.
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
      Navigator.pop(context, true);
    }
  }

  /// Asks for confirmation, deletes the item and closes the page.
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
          Navigator.pop(context, true);
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

  /// The scrolling form (header and sections) with the action bar below.
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
        QuizQuestionPicker(
          quizViewModel: quizViewModel,
          searchController: questionSearchController,
          enabled: !_isSaving,
        ),
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

  /// Hours and minutes side by side, with the total in minutes spelled out
  /// underneath.
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

  /// A small digits-only box with a unit label ("hr", "min") after it.
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

  /// Upcoming / Live / Pending choice chips.
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

  /// Free / Paid choice chips.
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

  /// A selectable chip used for status and type; the selected one is filled.
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
