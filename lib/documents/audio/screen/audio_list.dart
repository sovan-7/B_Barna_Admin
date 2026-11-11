import 'package:bbarna/core/widgets/list_page/paged_list_screen.dart';
import 'package:bbarna/documents/audio/model/audio_model.dart';
import 'package:bbarna/documents/audio/screen/add_audio.dart';
import 'package:bbarna/documents/audio/viewModel/audio_view_model.dart';
import 'package:bbarna/documents/audio/widgets/audio_card.dart';
import 'package:flutter/material.dart';

/// The audio clip list (sidebar module). All the behaviour lives in
/// [PagedListScreen]; this only supplies the audio-specific texts and card.
class AudioList extends StatelessWidget {
  const AudioList({super.key});

  @override
  Widget build(BuildContext context) {
    return PagedListScreen<AudioViewModel, AudioModel>(
      title: "Audio",
      subtitle: "Newest first. Free clips play without a purchase.",
      addButtonLabel: "NEW AUDIO",
      addScreenBuilder: (context) => const AddAudio(),
      searchHint: "Search by audio code",
      skeletonRowHeight: 88,
      emptyIcon: Icons.headphones_outlined,
      emptyTitle: "No audio yet",
      emptyMessage: "Upload a clip and students can play it inside the app.",
      filteredMessage:
          "No audio code starts with that. Search matches the code, not the title.",
      emptyAddLabel: "Add a clip",
      itemBuilder: (context, audio, onChanged) => AudioCard(
        key: ValueKey(audio.docId),
        audioData: audio,
        onChanged: onChanged,
      ),
    );
  }
}
