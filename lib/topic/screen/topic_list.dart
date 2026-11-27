import 'package:bbarna/core/widgets/list_page/paged_list_screen.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/topic/model/topic_model.dart';
import 'package:bbarna/topic/screen/add_topic.dart';
import 'package:bbarna/topic/viewModel/topic_view_model.dart';
import 'package:bbarna/topic/widgets/topic_card.dart';
import 'package:bbarna/core/widgets/list_page/admin_table.dart';
import 'package:bbarna/core/widgets/list_page/filter_chips.dart';
import 'package:bbarna/core/widgets/list_page/stats_strip.dart';
import 'package:bbarna/core/widgets/list_page/table_identity.dart';
import 'package:bbarna/core/widgets/card/card_chips.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The topic list (sidebar module). All the behaviour lives in
/// [PagedListScreen]; this only supplies the topic-specific texts and card,
/// and preloads the course list the Add/Edit Topic form needs.
class TopicList extends StatelessWidget {
  const TopicList({super.key});

  @override
  Widget build(BuildContext context) {
    return PagedListScreen<TopicViewModel, TopicModel>(
      title: "Topics",
      subtitle:
          "Newest first. Videos, audio, PDFs and quizzes hang off a topic.",
      addButtonLabel: "NEW TOPIC",
      addScreenBuilder: (context) => const AddTopic(),
      searchHint: "Search by topic code",
      skeletonRowHeight: 82,
      emptyIcon: Icons.topic_outlined,
      emptyTitle: "No topics yet",
      emptyMessage: "Topics sit under a unit, and content hangs off them.",
      filteredMessage:
          "No topic code starts with that. Search matches the code, not the name.",
      emptyAddLabel: "Add a topic",
      onFirstFrame: _preloadCourses,
      itemBuilder: (context, topic, onChanged) => TopicCard(
        key: ValueKey(topic.docId),
        topicData: topic,
        onChanged: onChanged,
      ),
      statTiles: (vm) => [
        StatTile.count(
            key: const Key('topic_stat_total'),
            label: "Total",
            count: vm.totalCount),
        StatTile.count(
            key: const Key('topic_stat_month'),
            label: "Added this month",
            count: vm.stats["month"]),
      ],
      chipOptions: const [
        FilterOption("all", "All", key: Key('topic_filter_all')),
        FilterOption("content", "Has content",
            key: Key('topic_filter_content')),
        FilterOption("empty", "No content", key: Key('topic_filter_empty')),
      ],
      chipMatches: (topic, filter) =>
          ContentKind.values.any((k) => topic.contentCodes(k).isNotEmpty) ==
          (filter == "content"),
      tableColumns: const [
        AdminTableColumn("Topic", flex: 5),
        AdminTableColumn("Code", width: 120),
        AdminTableColumn("Priority", width: 64),
        AdminTableColumn("Content", flex: 3),
        AdminTableColumn("", width: 108, alignment: Alignment.centerRight),
      ],
      rowId: (topic) => topic.docId,
      rowKeyPrefix: "topic",
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
          icon: Icons.topic_outlined,
          iconColor: AppTokens.accentInk,
        ),
        CodeChip(topic.code),
        TableText("${topic.displayPriority}"),
        topicContentChips(topic),
        topicActions(context, topic, onChanged, hovered),
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
}
