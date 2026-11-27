import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/topic/model/topic_model.dart';
import 'package:flutter/material.dart';

/// Tab text and icon for each kind of content.
const Map<ContentKind, (String, IconData)> contentTabMeta = {
  ContentKind.pdf: ("PDFs", Icons.picture_as_pdf_outlined),
  ContentKind.video: ("Videos", Icons.smart_display_outlined),
  ContentKind.audio: ("Audio", Icons.headphones_outlined),
  ContentKind.quiz: ("Quizzes", Icons.quiz_outlined),
};

/// One tab of [ContentTabs].
class ContentTab {
  /// Tab text, e.g. "PDFs".
  final String label;

  /// Tab icon.
  final IconData icon;

  /// How many items the tab starts with (before the section reports).
  final int initialCount;

  /// Builds the tab's section. It must call the callback it is given when
  /// its unsaved state or row count changes (`onStateChanged`).
  final Widget Function(void Function(bool dirty, int count) onState) builder;

  const ContentTab({
    required this.label,
    required this.icon,
    required this.initialCount,
    required this.builder,
  });
}

/// The content of a topic as tabs (PDFs / Videos / Audio / Quizzes), each
/// with its count and a dot while it has unsaved changes.
///
/// Every section stays mounted while another tab shows, so switching tabs
/// never throws away rows that have not been saved yet.
class ContentTabs extends StatefulWidget {
  /// The tabs, left to right.
  final List<ContentTab> tabs;

  const ContentTabs({required this.tabs, super.key});

  @override
  State<ContentTabs> createState() => _ContentTabsState();
}

class _ContentTabsState extends State<ContentTabs> {
  /// The tab showing.
  int _index = 0;

  /// What each section last reported: unsaved?, how many rows.
  late final List<(bool, int)> _state = [
    for (final ContentTab tab in widget.tabs) (false, tab.initialCount),
  ];

  /// What section [i] calls when its unsaved state or row count changes.
  void Function(bool, int) _reporter(int i) => (dirty, count) {
        if (!mounted || _state[i] == (dirty, count)) return;
        setState(() => _state[i] = (dirty, count));
      };

  @override
  Widget build(BuildContext context) {
    final bool currentDirty = _state[_index].$1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTokens.hairline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int i = 0; i < widget.tabs.length; i++) _tab(i),
                    ],
                  ),
                ),
              ),
              if (currentDirty)
                const Padding(
                  padding: EdgeInsets.only(left: AppTokens.gapSm),
                  child: Text("Unsaved changes",
                      key: Key('content_tabs_unsaved'),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTokens.warningText)),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.gapMd),
        // Rebuilt every time (so new titles and errors reach them), but
        // always in the same place, so each keeps its state — unsaved rows
        // included — while another tab shows.
        for (int i = 0; i < widget.tabs.length; i++)
          Visibility(
            visible: i == _index,
            maintainState: true,
            child: widget.tabs[i].builder(_reporter(i)),
          ),
      ],
    );
  }

  /// One tab: icon, label, count, and a dot while it has unsaved changes.
  Widget _tab(int i) {
    final ContentTab tab = widget.tabs[i];
    final bool selected = i == _index;
    final (bool dirty, int count) = _state[i];
    final Color color = selected ? AppTokens.ink : AppTokens.inkMuted;

    return InkWell(
      key: Key('content_tab_$i'),
      onTap: () => setState(() => _index = i),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
        margin: const EdgeInsets.only(right: AppTokens.gapLg),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
                width: 2,
                color: selected ? AppTokens.accent : Colors.transparent),
          ),
        ),
        child: Row(
          children: [
            Icon(tab.icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(tab.label,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: color)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: AppTokens.surfaceMuted,
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              ),
              child: Text("$count",
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.inkMuted)),
            ),
            if (dirty) ...[
              const SizedBox(width: 6),
              Container(
                key: Key('content_tab_dirty_$i'),
                height: 7,
                width: 7,
                decoration: const BoxDecoration(
                    color: AppTokens.warningText, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The card at the top of a topic's details: back button, an icon, the
/// name and code, where it sits (course › subject › unit), and a hint.
class TopicHeaderCard extends StatelessWidget {
  final String name;
  final String code;
  final String courseName;
  final String subjectName;
  final String unitName;
  final String hint;

  /// Opens the topic's edit page; no Edit button when null.
  final VoidCallback? onEdit;

  const TopicHeaderCard({
    required this.name,
    required this.code,
    required this.courseName,
    required this.subjectName,
    required this.unitName,
    required this.hint,
    this.onEdit,
    super.key,
  });

  static String _or(String value, String fallback) =>
      value.trim().isEmpty || value == stringDefault ? fallback : value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTokens.gapMd),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppTokens.hairline),
        boxShadow: AppTokens.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormBackButton(onTap: () => Navigator.pop(context)),
          const SizedBox(width: AppTokens.gapMd),
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: AppTokens.accentTint,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            ),
            child: const Icon(Icons.topic_outlined,
                size: 22, color: AppTokens.accent),
          ),
          const SizedBox(width: AppTokens.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(_or(name, "Topic"),
                          overflow: TextOverflow.ellipsis,
                          style: AppTokens.pageTitle),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTokens.surfaceMuted,
                        borderRadius:
                            BorderRadius.circular(AppTokens.radiusPill),
                        border: Border.all(color: AppTokens.hairline),
                      ),
                      child: Text(code,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: AppTokens.inkMuted)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  "${_or(courseName, 'No course')}  ›  "
                  "${_or(subjectName, 'No subject')}  ›  "
                  "${_or(unitName, 'No unit')}",
                  overflow: TextOverflow.ellipsis,
                  style: AppTokens.pageSubtitle,
                ),
                const SizedBox(height: 3),
                Text(hint,
                    style: const TextStyle(
                        fontSize: 12, color: AppTokens.inkFaint)),
              ],
            ),
          ),
          if (onEdit != null) ...[
            const SizedBox(width: AppTokens.gapMd),
            OutlinedButton.icon(
              key: const Key('topic_header_edit'),
              onPressed: onEdit,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTokens.ink,
                side: const BorderSide(color: AppTokens.hairline),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
              ),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text("Edit topic", style: TextStyle(fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }
}
