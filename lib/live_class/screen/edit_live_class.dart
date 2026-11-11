import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:bbarna/live_class/widgets/live_class_form.dart';
import 'package:flutter/material.dart';

/// Edit Class screen — the shared [LiveClassForm] pre-populated with
/// [liveClassData]; also offers Delete.
class EditLiveClass extends StatelessWidget {
  /// The item being edited.
  final LiveClassModel liveClassData;
  const EditLiveClass({required this.liveClassData, super.key});

  @override
  Widget build(BuildContext context) => LiveClassForm(existing: liveClassData);
}
