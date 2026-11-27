import 'package:bbarna/core/widgets/list_page/paged_list_screen.dart';
import 'package:bbarna/documents/video/model/video_model.dart';
import 'package:bbarna/documents/video/screen/add_video.dart';
import 'package:bbarna/documents/video/viewModel/video_view_model.dart';
import 'package:bbarna/documents/video/widgets/video_card.dart';
import 'package:bbarna/core/widgets/card/card_chips.dart';
import 'package:bbarna/documents/media_table.dart';
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
      statTiles: (vm) => mediaStatTiles("video", vm.totalCount, vm.stats),
      chipOptions: accessChipOptions("video"),
      chipMatches: (video, filter) =>
          accessChipMatches(video.videoType, filter),
      tableColumns: mediaColumns("Video"),
      rowId: (video) => video.docId,
      rowKeyPrefix: "video",
      tableMinWidth: 720,
      rowCells: (context, video, hovered, onChanged) => [
        mediaIdentity(
            title: video.title,
            description: video.description,
            icon: Icons.smart_display_outlined,
            color: const Color(0xFFD92D20)),
        CodeChip(video.code, copyable: true),
        accessPill(video.videoType),
        addedCell(video.timeStamp),
        openLinkCell(
            video.link, Key('video_open_${video.docId}'), "Open the video"),
        videoActions(context, video, onChanged, hovered),
      ],
    );
  }
}
