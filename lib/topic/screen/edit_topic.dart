import 'package:bbarna/topic/model/topic_model.dart';
import 'package:bbarna/topic/widgets/topic_form.dart';
import 'package:flutter/material.dart';

/// Edit Topic screen — the shared [TopicForm] pre-populated with
/// [topicData]; also offers Delete and a way through to the content it
/// holds.
class EditTopic extends StatelessWidget {
  /// The item being edited.
  final TopicModel topicData;
  const EditTopic({required this.topicData, super.key});

  @override
  Widget build(BuildContext context) => TopicForm(existing: topicData);
}
