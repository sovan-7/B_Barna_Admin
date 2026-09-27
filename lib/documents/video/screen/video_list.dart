import 'package:bbarna/core/widgets/list_page/paged_list_screen.dart';
import 'package:bbarna/documents/video/model/video_model.dart';
import 'package:bbarna/documents/video/screen/add_video.dart';
import 'package:bbarna/documents/video/viewModel/video_view_model.dart';
import 'package:bbarna/documents/video/widgets/video_card.dart';
import 'package:flutter/material.dart';

/// The video list (sidebar module). All the behaviour lives in
/// [PagedListScreen]; this only supplies the video-specific texts and card.
class VideoList extends StatelessWidget {
  const VideoList({super.key});

  @override
  Widget build(BuildContext context) {
    return PagedListScreen<VideoViewModel, VideoModel>(
      title: "Videos",
      subtitle: "Newest first. Free videos play without a purchase.",
      addButtonLabel: "NEW VIDEO",
      addScreenBuilder: (context) => const AddVideo(),
      searchHint: "Search by video code",
      skeletonRowHeight: 86,
      emptyIcon: Icons.video_library_outlined,
      emptyTitle: "No videos yet",
      emptyMessage: "Videos are linked, not uploaded — add one with its URL.",
      filteredMessage:
          "No video code starts with that. Search matches the code, not the title.",
      emptyAddLabel: "Add a video",
      itemBuilder: (context, video, onChanged) => VideoCard(
        key: ValueKey(video.docId),
        videoData: video,
        onChanged: onChanged,
      ),
    );
  }
}
