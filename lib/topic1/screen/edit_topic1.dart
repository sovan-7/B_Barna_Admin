import 'package:bbarna/topic1/model/topic1_model.dart';
import 'package:bbarna/topic1/widgets/topic1_form.dart';
import 'package:flutter/material.dart';

/// Edit Topic1 screen — the shared [Topic1Form] pre-populated with
/// [topicData]; also offers Delete and a way through to the content it
/// holds.
class EditTopic1 extends StatelessWidget {
  /// The item being edited.
  final Topic1Model topicData;
  const EditTopic1({required this.topicData, super.key});

  @override
  Widget build(BuildContext context) => Topic1Form(existing: topicData);
}
