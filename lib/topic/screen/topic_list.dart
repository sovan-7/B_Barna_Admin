import 'package:bbarna/core/widgets/list_page/paged_list_screen.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/topic/model/topic_model.dart';
import 'package:bbarna/topic/screen/add_topic.dart';
import 'package:bbarna/topic/viewModel/topic_view_model.dart';
import 'package:bbarna/topic/widgets/topic_card.dart';
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
