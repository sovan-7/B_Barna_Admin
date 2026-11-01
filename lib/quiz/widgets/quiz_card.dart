import 'package:bbarna/core/widgets/card/admin_card_shell.dart';
import 'package:bbarna/core/widgets/card/card_actions.dart';
import 'package:bbarna/core/widgets/card/card_chips.dart';
import 'package:bbarna/core/widgets/card/card_helpers.dart';
import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/quiz/model/quiz_model.dart';
import 'package:bbarna/quiz/screen/add_quiz.dart';
import 'package:bbarna/quiz/screen/edit_quiz.dart';
import 'package:bbarna/quiz/viewModel/quiz_view_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/navigation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// One row of the quiz list: name, code and the numbers that define a
/// quiz (length, marks, question count); status and FREE/PAID chips;
/// edit / delete buttons.
class QuizCard extends StatefulWidget {
  /// The item shown in this row.
  final QuizModel quizData;

  /// Called after an edit or delete so the list can reload.
  final VoidCallback onChanged;

  const QuizCard({required this.quizData, required this.onChanged, super.key});

  @override
  State<QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<QuizCard> {
  /// Shortcut for the item shown.
  QuizModel get _data => widget.quizData;

  @override
  Widget build(BuildContext context) {
    return AdminCardShell(
      builder: (context, layout) => CardRowLayout(
        layout: layout,
        identity: _identity(),
        chips: _chips(),
        actions: _actions(layout.showActions),
      ),
    );
  }

  /// Left part of the row: picture or icon, name, code and details.
  Widget _identity() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: AppTokens.surfaceMuted,
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            border: Border.all(color: AppTokens.hairline),
          ),
          child: const Icon(Icons.quiz_outlined,
              size: 19, color: AppTokens.inkMuted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: SelectableLabel(
                      _data.name,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppTokens.ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CodeChip(_data.code),
                ],
              ),
              const SizedBox(height: 5),
              // The shape of the quiz in one line: time, marks, questions.
              Wrap(
                spacing: 12,
                runSpacing: 3,
                children: [
                  _fact(Icons.timer_outlined, formatDuration(_data.totalTime)),
                  _fact(Icons.help_outline, _questionsLabel()),
                  _fact(Icons.star_outline, _marksLabel()),
                  if (_data.numberDeduction > 0)
                    _fact(Icons.remove_circle_outline,
                        "-${_data.numberDeduction} per wrong answer"),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The stored question count (`total_question`) and the questions actually
  /// attached can disagree on older quizzes; say so when they differ.
  String _questionsLabel() {
    final int attached = _data.questionCodeList.length;
    final int stated = _data.totalQuestion;
    if (stated > 0 && stated != attached) {
      return "$attached attached (set to $stated)";
    }
    return "$attached question${attached == 1 ? '' : 's'}";
  }

  /// Marks, plus the negative marking if any, e.g. "100 marks · −1".
  String _marksLabel() =>
      _data.totalMarks > 0 ? "${_data.totalMarks} marks" : "No marks set";

  /// A small grey icon + text pair (e.g. "90 min").
  Widget _fact(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTokens.inkFaint),
        const SizedBox(width: 5),
        // Capped: a Wrap only wraps *between* children, so one over-wide
        // child still overflows the row it lands on.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 190),
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 11.5, color: AppTokens.inkMuted)),
        ),
      ],
    );
  }

  /// Status chips shown beside (or, when compact, under) the identity.
  Widget _chips() {
    final bool isFree = _data.type.toUpperCase() == "FREE";
    final Color typeColor =
        isFree ? const Color(0xFF108460) : const Color(0xFFB54708);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _chip(
          icon: statusIcon(_data.status),
          label: _data.status.isEmpty || _data.status == stringDefault
              ? "No status"
              : _data.status.toUpperCase(),
          color: statusColor(_data.status),
        ),
        _chip(
          icon: isFree ? Icons.lock_open_outlined : Icons.paid_outlined,
          label: _data.type.isEmpty || _data.type == stringDefault
              ? "No type"
              : _data.type.toUpperCase(),
          color: typeColor,
        ),
      ],
    );
  }

  /// A small pill with an icon and label.
  Widget _chip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: color)),
        ],
      ),
    );
  }

  /// Row buttons; faded in on hover, always shown on compact screens.
  Widget _actions(bool visible) {
    return CardActions(
      visible: visible,
      buttons: [
        CardIconButton(
          buttonKey: Key('quiz_duplicate_${_data.docId}'),
          icon: Icons.copy_all_outlined,
          tooltip: "Duplicate quiz",
          color: AppTokens.inkMuted,
          onTap: _openDuplicate,
        ),
        CardEditButton(
          buttonKey: Key('quiz_edit_${_data.docId}'),
          tooltip: "Edit quiz",
          onTap: _openEdit,
        ),
        CardDeleteButton(
          buttonKey: Key('quiz_delete_${_data.docId}'),
          tooltip: "Delete quiz",
          onTap: _confirmDelete,
        ),
      ],
    );
  }

  /// Opens the edit screen; the list reloads if it saved or deleted
  /// something.
  void _openEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditQuiz(quizData: _data)),
    ).ifSaved(widget.onChanged);
  }

  /// Opens Add Quiz prefilled from this quiz; the list reloads if the copy
  /// was saved.
  void _openDuplicate() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddQuiz(copyOf: _data)),
    ).ifSaved(widget.onChanged);
  }

  /// Asks for confirmation, then deletes this item.
  void _confirmDelete() {
    final QuizViewModel quizViewModel =
        Provider.of<QuizViewModel>(context, listen: false);
    final String docId = _data.docId;

    confirmDelete(
      title: _data.name,
      delete: () => quizViewModel.deleteQuiz(docId),
      successMessage: "Quiz deleted successfully",
    );
  }
}

/// "1h 30m" from a whole number of minutes — the form collects hours and
/// minutes separately and stores their sum.
String formatDuration(int minutes) {
  if (minutes <= 0) return "No time limit";
  final int hours = minutes ~/ 60;
  final int rest = minutes % 60;
  if (hours == 0) return "${rest}m";
  if (rest == 0) return "${hours}h";
  return "${hours}h ${rest}m";
}

/// Accent colour for a quiz status (LIVE / UPCOMING / PENDING).
Color statusColor(String status) {
  switch (status.toUpperCase()) {
    case "LIVE":
      return const Color(0xFFE0393E);
    case "UPCOMING":
      return const Color(0xFF2563EB);
    case "PENDING":
      return const Color(0xFFB54708);
    default:
      return AppTokens.inkFaint;
  }
}

/// Icon for a quiz status (LIVE / UPCOMING / PENDING).
IconData statusIcon(String status) {
  switch (status.toUpperCase()) {
    case "LIVE":
      return Icons.sensors;
    case "UPCOMING":
      return Icons.event_outlined;
    case "PENDING":
      return Icons.hourglass_empty;
    default:
      return Icons.help_outline;
  }
}
