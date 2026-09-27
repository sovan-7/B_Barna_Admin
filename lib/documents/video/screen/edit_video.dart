import 'package:bbarna/documents/video/model/video_model.dart';
import 'package:bbarna/documents/video/widgets/video_form.dart';
import 'package:flutter/material.dart';

/// Edit Video screen — the shared [VideoForm] pre-populated with
/// [videoData]; also offers Delete.
class EditVideo extends StatelessWidget {
  /// The item being edited.
  final VideoModel videoData;
  const EditVideo({required this.videoData, super.key});

  @override
  Widget build(BuildContext context) => VideoForm(existing: videoData);
}
