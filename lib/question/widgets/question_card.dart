import 'package:bbarna/core/widgets/card/admin_card_shell.dart';
import 'package:bbarna/core/widgets/card/card_actions.dart';
import 'package:bbarna/core/widgets/card/card_helpers.dart';
import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/question/model/question.dart';
import 'package:bbarna/question/model/question_draft.dart';
import 'package:bbarna/question/screen/edit_question.dart';
import 'package:bbarna/question/viewModel/question_view_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// One row of the question list.
///
/// Shows the question as one line of plain text (not rendered HTML, so
/// every row is the same height), plus whether all four options are
/// filled in and which one is marked correct.
class QuestionCard extends StatefulWidget {
  /// The item shown in this row.
  final Question questionData;

  /// Called after an edit or delete so the list can reload.
  final VoidCallback onChanged;

  const QuestionCard(
      {required this.questionData, required this.onChanged, super.key});

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  /// Shortcut for the item shown.
  Question get _data => widget.questionData;

  @override
  Widget build(BuildContext context) {
    return AdminCardShell(
      builder: (context, layout) => CardRowLayout(
        layout: layout,
        identity: _identity(),
        chips: _chips(),
        actions: _actions(layout.showActions),
        chipsFlex: 3,
      ),
    );
  }

  /// Left part of the row: picture or icon, name, code and details.
  Widget _identity() {
    final String text = QuestionDraft.plainText(_data.question);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: AppTokens.surfaceMuted,
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            border: Border.all(color: AppTokens.hairline),
          ),
          child: const Icon(Icons.help_outline,
              size: 17, color: AppTokens.inkMuted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableLabel(
                _data.questionCode.isEmpty ||
                        _data.questionCode == stringDefault
                    ? "No code"
                    : _data.questionCode,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppTokens.inkMuted),
              ),
              const SizedBox(height: 3),
              SelectableLabel(
                text.isEmpty ? "No question text" : text,
                maxLines: 2,
                style: TextStyle(
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: text.isEmpty ? AppTokens.danger : AppTokens.ink),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Status chips shown beside (or, when compact, under) the identity.
  Widget _chips() {
    final QuestionOption? answer = QuestionDraft.answerOf(_data);
    final int filled = QuestionOption.values
        .where((option) => QuestionDraft.plainText(switch (option) {
              QuestionOption.a => _data.option1,
              QuestionOption.b => _data.option2,
              QuestionOption.c => _data.option3,
              QuestionOption.d => _data.option4,
            })
                .isNotEmpty)
        .length;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _chip(
          icon: filled == 4 ? Icons.checklist : Icons.warning_amber_outlined,
          label: filled == 4 ? "4 options" : "$filled of 4 options",
          color: filled == 4 ? AppTokens.inkMuted : const Color(0xFFB54708),
          filled: filled != 4,
        ),
        // A question with no answer marked is one no student can get right,
        // so say so.
        _chip(
          icon:
              answer == null ? Icons.error_outline : Icons.check_circle_outline,
          label: answer == null ? "No answer set" : "Answer ${answer.label}",
          color: answer == null ? AppTokens.danger : const Color(0xFF108460),
          filled: true,
        ),
      ],
    );
  }

  /// A small pill with an icon and label.
  Widget _chip({
    required IconData icon,
    required String label,
    required Color color,
    bool filled = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: .10) : AppTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(
            color: filled ? color.withValues(alpha: .28) : AppTokens.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  /// Row buttons; faded in on hover, always shown on compact screens.
  Widget _actions(bool visible) {
    return CardActions(
      visible: visible,
      buttons: [
        CardEditButton(
          buttonKey: Key('question_edit_${_data.docId}'),
          tooltip: "Edit question",
          onTap: _openEdit,
        ),
        CardDeleteButton(
          buttonKey: Key('question_delete_${_data.docId}'),
          tooltip: "Delete question",
          onTap: _confirmDelete,
        ),
      ],
    );
  }

  /// Opens the edit screen; the list reloads when it closes.
  void _openEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => EditQuestion(questionData: _data)),
    ).whenComplete(widget.onChanged);
  }

  /// Asks for confirmation, then deletes this item.
  void _confirmDelete() {
    final QuestionViewModel questionViewModel =
        Provider.of<QuestionViewModel>(context, listen: false);
    // Captured up front (by id, not list position) so a refresh while the
    // dialog is open cannot change which question gets deleted.
    final String docId = _data.docId;

    confirmDelete(
      title: _data.questionCode,
      delete: () => questionViewModel.deleteQuestion(docId),
      successMessage: "Question deleted successfully",
    );
  }
}
