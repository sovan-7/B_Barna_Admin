import 'package:bbarna/core/widgets/list_page/paged_list_screen.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/topic1/model/topic1_model.dart';
import 'package:bbarna/topic1/repo/topic1_repo.dart';
import 'package:bbarna/topic1/screen/add_topic1.dart';
import 'package:bbarna/topic1/viewModel/topic1_view_model.dart';
import 'package:bbarna/topic1/widgets/topic1_card.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:bbarna/core/widgets/list_page/admin_table.dart';
import 'package:bbarna/core/widgets/list_page/filter_chips.dart';
import 'package:bbarna/core/widgets/list_page/stats_strip.dart';
import 'package:bbarna/core/widgets/list_page/table_identity.dart';
import 'package:bbarna/core/widgets/card/card_chips.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The New Topics list (sidebar module; `Topic1…` in code). All the
/// behaviour lives in [PagedListScreen]; this only supplies the texts and
/// card, the one-time "copy from Topics" action (hidden; see
/// [showCopyButton]), and preloads the course list the Add/Edit form needs.
class Topic1List extends StatelessWidget {
  /// Whether "COPY FROM TOPICS" shows beside "NEW TOPIC". Hidden for now;
  /// the copy action and its code are kept, so setting the default back to
  /// true brings the button back.
  final bool showCopyButton;

  const Topic1List({this.showCopyButton = false, super.key});

  @override
  Widget build(BuildContext context) {
    return PagedListScreen<Topic1ViewModel, Topic1Model>(
      title: "New Topics",
      subtitle: "Newest first. PDFs are uploaded and videos are YouTube "
          "links, straight on the topic.",
      addButtonLabel: "NEW TOPIC",
      addScreenBuilder: (context) => const AddTopic1(),
      searchHint: "Search by topic code",
      skeletonRowHeight: 82,
      emptyIcon: Icons.topic_outlined,
      emptyTitle: "No topics yet",
      emptyMessage:
          "Topics sit under a unit; upload PDFs and add YouTube links to them.",
      filteredMessage:
          "No topic code starts with that. Search matches the code, not the name.",
      emptyAddLabel: "Add a topic",
      onFirstFrame: _preloadCourses,
      extraHeaderAction: showCopyButton
          ? (context, viewModel) => _CopyButton(
                copying: viewModel.copying,
                onPressed: () => _confirmCopy(context, viewModel),
              )
          : null,
      itemBuilder: (context, topic, onChanged) => Topic1Card(
        key: ValueKey(topic.docId),
        topicData: topic,
        onChanged: onChanged,
      ),
      statTiles: (vm) => [
        StatTile.count(
            key: const Key('topic1_stat_total'),
            label: "Total",
            count: vm.totalCount),
        StatTile.count(
            key: const Key('topic1_stat_month'),
            label: "Added this month",
            count: vm.stats["month"]),
      ],
      chipOptions: const [
        FilterOption("all", "All", key: Key('topic1_filter_all')),
        FilterOption("content", "Has content",
            key: Key('topic1_filter_content')),
        FilterOption("empty", "No content", key: Key('topic1_filter_empty')),
      ],
      chipMatches: (topic, filter) =>
          (topic.contentCount > 0) == (filter == "content"),
      tableColumns: const [
        AdminTableColumn("Topic", flex: 5),
        AdminTableColumn("Code", width: 120),
        AdminTableColumn("Priority", width: 64),
        AdminTableColumn("Content", flex: 3),
        AdminTableColumn("", width: 108, alignment: Alignment.centerRight),
      ],
      rowId: (topic) => topic.docId,
      rowKeyPrefix: "topic1",
      tableMinWidth: 780,
      rowCells: (context, topic, hovered, onChanged) => [
        TableIdentity(
          title: topic.name,
          subtitle: [
                if (TableIdentity.hasText(topic.subjectName)) topic.subjectName,
                if (TableIdentity.hasText(topic.unitName)) topic.unitName,
              ].join(" › ") +
              (topic.unitCodeList.length > 1
                  ? " · also in ${topic.unitCodeList.length - 1} more"
                  : ""),
          icon: Icons.checklist_rtl,
          iconColor: AppTokens.accent,
        ),
        CodeChip(topic.code),
        TableText("${topic.displayPriority}"),
        topic1ContentChips(topic),
        topic1Actions(context, topic, onChanged, hovered),
      ],
    );
  }

  /// The add/edit form needs the course list for its course picker; load
  /// it once if nothing has yet.
  static void _preloadCourses(BuildContext context) {
    final CourseViewModel courseViewModel =
        Provider.of<CourseViewModel>(context, listen: false);
    if (courseViewModel.allCourses.isEmpty) courseViewModel.getCourseList();
  }

  /// Asks before copying the Topics module's topics in, then copies and
  /// says how many were copied (the view model reports a failure).
  static Future<void> _confirmCopy(
      BuildContext context, Topic1ViewModel viewModel) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text("Copy topics from Topics?"),
        content: const Text(
            "Every topic in the Topics module that isn't here yet is copied "
            "in. Its PDFs and YouTube videos are stored on the topic; audio "
            "and quizzes stay attached by code. Missing or locked PDFs and "
            "videos that aren't on YouTube are left out. Topics whose code "
            "is already here are skipped, and the Topics module is not "
            "changed."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            key: const Key('topic1_copy_confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Copy"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final TopicsCopyResult? result = await viewModel.copyFromTopics();
    if (result == null) return;
    Helper.showInfoMessage(msg: copyResultMessage(result));
  }

  /// The toast after a copy: how many topics came over and, if any, how
  /// many PDFs/videos were left out.
  @visibleForTesting
  static String copyResultMessage(TopicsCopyResult result) {
    if (result.copied == 0) {
      return "Nothing to copy: every topic is already here";
    }
    final String copied = "Copied ${result.copied} "
        "${result.copied == 1 ? "topic" : "topics"} from Topics";
    if (result.leftOut == 0) return copied;
    return "$copied · ${result.leftOut} "
        "${result.leftOut == 1 ? "PDF/video" : "PDFs/videos"} left out "
        "(missing, locked or not YouTube)";
  }
}

/// "COPY FROM TOPICS" beside "NEW TOPIC"; just the icon on narrow windows,
/// where both labels do not fit next to the title. Disabled, with a
/// spinner, while a copy runs.
class _CopyButton extends StatelessWidget {
  final bool copying;
  final VoidCallback onPressed;
  const _CopyButton({required this.copying, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final bool narrow = MediaQuery.sizeOf(context).width < 700;
    final ButtonStyle style = OutlinedButton.styleFrom(
      foregroundColor: AppTokens.ink,
      side: const BorderSide(color: AppTokens.hairline),
      padding: EdgeInsets.symmetric(horizontal: narrow ? 10 : 14, vertical: 14),
      minimumSize: Size.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
    );
    final Widget icon = copying
        ? const SizedBox(
            width: 17,
            height: 17,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.copy_all_outlined, size: 17);
    final VoidCallback? action = copying ? null : onPressed;

    return Tooltip(
      message: "Copy the topics from the Topics module",
      child: narrow
          ? OutlinedButton(
              key: const Key('topic1_copy_button'),
              onPressed: action,
              style: style,
              child: icon,
            )
          : OutlinedButton.icon(
              key: const Key('topic1_copy_button'),
              onPressed: action,
              style: style,
              icon: icon,
              label: Text(copying ? "COPYING…" : "COPY FROM TOPICS",
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
    );
  }
}
