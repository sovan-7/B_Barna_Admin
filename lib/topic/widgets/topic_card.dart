import 'package:bbarna/core/widgets/card/admin_card_shell.dart';
import 'package:bbarna/core/widgets/card/card_actions.dart';
import 'package:bbarna/core/widgets/card/card_chips.dart';
import 'package:bbarna/core/widgets/card/card_helpers.dart';
import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/topic/model/topic_model.dart';
import 'package:bbarna/topic/screen/edit_topic.dart';
import 'package:bbarna/topic/screen/topic_details.dart';
import 'package:bbarna/topic/viewModel/topic_view_model.dart';
import 'package:bbarna/utils/navigation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// One row of the topic list: name, code and its course › subject › unit
/// breadcrumb; priority and counts of attached videos / audio / PDFs /
/// quizzes; buttons to manage content, edit and delete.
class TopicCard extends StatefulWidget {
  /// The item shown in this row.
  final TopicModel topicData;

  /// Called after something changed, so the list can refresh.
  final VoidCallback onChanged;

  const TopicCard(
      {required this.topicData, required this.onChanged, super.key});

  @override
  State<TopicCard> createState() => _TopicCardState();
}

class _TopicCardState extends State<TopicCard> {
  /// Shortcut for the item shown.
  TopicModel get _data => widget.topicData;

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
        _priorityBadge(),
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
              const SizedBox(height: 4),
              // Where the topic sits: course › subject › unit, as one
              // breadcrumb line.
              Row(
                children: [
                  const Icon(Icons.account_tree_outlined,
                      size: 12, color: AppTokens.inkFaint),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      _breadcrumb(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppTokens.inkMuted),
                    ),
                  ),
                ],
              ),
              if (_data.unitCodeList.length > 1) ...[
                const SizedBox(height: 4),
                Text(
                  // A topic can be shared across several units.
                  "Also in ${_data.unitCodeList.length - 1} more unit"
                  "${_data.unitCodeList.length - 1 == 1 ? '' : 's'}",
                  style: const TextStyle(
                      fontSize: 11.5, color: AppTokens.inkFaint),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// "Course › Subject" style path of where this item sits.
  String _breadcrumb() {
    String or(String value, String fallback) =>
        value.isEmpty || value == stringDefault ? fallback : value;
    return "${or(_data.courseName, 'No course')}"
        "  ›  ${or(_data.subjectName, 'No subject')}"
        "  ›  ${or(_data.unitName, 'No unit')}";
  }

  /// Display priority, shown as a number in a square badge.
  Widget _priorityBadge() {
    return Container(
      height: 46,
      width: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: AppTokens.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("P",
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppTokens.inkFaint)),
          Text("${_data.displayPriority}",
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTokens.inkMuted)),
        ],
      ),
    );
  }

  /// What is attached: one chip per content kind that has items (empty
  /// kinds are left out), or a "Nothing attached" note.
  Widget _chips() {
    final List<Widget> chips = <Widget>[];
    for (final ContentKind kind in ContentKind.values) {
      final int count = _data.contentCodes(kind).length;
      if (count == 0) continue;
      chips.add(_countChip(kind, count));
    }

    if (chips.isEmpty) {
      return Wrap(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTokens.surfaceMuted,
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              border: Border.all(color: AppTokens.hairline),
            ),
            child: const Text("No content yet",
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.inkFaint)),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: chips,
    );
  }

  /// Icon for each kind of attached content.
  static const Map<ContentKind, IconData> _kindIcons = {
    ContentKind.video: Icons.play_circle_outline,
    ContentKind.audio: Icons.graphic_eq,
    ContentKind.pdf: Icons.picture_as_pdf_outlined,
    ContentKind.quiz: Icons.quiz_outlined,
  };

  /// How many items of [kind] are attached to the topic.
  Widget _countChip(ContentKind kind, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: AppTokens.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_kindIcons[kind], size: 12, color: AppTokens.inkMuted),
          const SizedBox(width: 5),
          Text("${kind.label} $count",
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.inkMuted)),
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
          buttonKey: Key('topic_content_${_data.docId}'),
          icon: Icons.playlist_add,
          tooltip: "Manage content",
          color: AppTokens.inkMuted,
          onTap: _openContent,
        ),
        CardEditButton(
          buttonKey: Key('topic_edit_${_data.docId}'),
          tooltip: "Edit topic",
          onTap: _openEdit,
        ),
        CardDeleteButton(
          buttonKey: Key('topic_delete_${_data.docId}'),
          tooltip: "Delete topic",
          onTap: _confirmDelete,
        ),
      ],
    );
  }

  /// Opens the topic details screen to manage attached content. No reload
  /// afterwards: content saves update this topic in place.
  void _openContent() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TopicDetails(topicData: _data)),
    );
  }

  /// Opens the edit screen; the list reloads if it saved or deleted
  /// something.
  void _openEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditTopic(topicData: _data)),
    ).ifSaved(widget.onChanged);
  }

  /// Asks for confirmation, then deletes this item.
  void _confirmDelete() {
    final TopicViewModel topicViewModel =
        Provider.of<TopicViewModel>(context, listen: false);
    final String docId = _data.docId;

    confirmDelete(
      title: _data.name,
      delete: () => topicViewModel.deleteTopic(docId),
      successMessage: "Topic deleted successfully",
    );
  }
}
