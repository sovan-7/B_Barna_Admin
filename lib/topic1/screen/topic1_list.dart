import 'package:bbarna/core/widgets/list_page/paged_list_screen.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/topic1/model/topic1_model.dart';
import 'package:bbarna/topic1/screen/add_topic1.dart';
import 'package:bbarna/topic1/viewModel/topic1_view_model.dart';
import 'package:bbarna/topic1/widgets/topic1_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The New Topics list (sidebar module; `Topic1…` in code). All the
/// behaviour lives in [PagedListScreen]; this only supplies the texts and
/// card, and preloads the course list the Add/Edit form needs.
class Topic1List extends StatelessWidget {
  const Topic1List({super.key});

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
      itemBuilder: (context, topic, onChanged) => Topic1Card(
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
