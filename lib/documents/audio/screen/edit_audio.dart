import 'package:bbarna/documents/audio/model/audio_model.dart';
import 'package:bbarna/documents/audio/widgets/audio_form.dart';
import 'package:flutter/material.dart';

/// Edit Audio screen — the shared [AudioForm] pre-populated with
/// [audioData]; also offers Delete.
class EditAudio extends StatelessWidget {
  /// The item being edited.
  final AudioModel audioData;
  const EditAudio({required this.audioData, super.key});

  @override
  Widget build(BuildContext context) => AudioForm(existing: audioData);
}
