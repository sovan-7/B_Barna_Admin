import 'package:bbarna/core/widgets/form/form_fields.dart';
import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/subject/subject_field_rules.dart';
import 'package:bbarna/topic1/model/topic1_model.dart';
import 'package:bbarna/topic1/widgets/topic1_section_card.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';

/// The fields of a video row that can carry an inline error.
enum _VideoField { title, link, type }

/// One row being edited.
class _VideoRow {
  /// [Topic1Video.id]; new rows get a fresh one.
  final String id;

  /// Title being typed.
  final TextEditingController title;

  /// YouTube link being typed or pasted.
  final TextEditingController link;

  /// "FREE" / "PAID", or null until chosen.
  String? type;

  _VideoRow.fromVideo(Topic1Video video)
      : id = video.id,
        title = TextEditingController(text: video.title),
        link = TextEditingController(text: video.link),
        type = topic1AccessTypes.contains(video.type) ? video.type : null;

  _VideoRow.fresh()
      : id = newTopic1ItemId(),
        title = TextEditingController(),
        link = TextEditingController(),
        type = null;

  void dispose() {
    title.dispose();
    link.dispose();
  }
}

/// The YouTube videos on a Topic1: one row per video with its title, link
/// and Free/Paid; "Add a video" and Save. A link is accepted only if it is
/// a YouTube video, and is saved in the one form the student app's player
/// understands (`SubjectVideoLink.normalize`). Saved rows open folded to a
/// one-line summary; tap one to edit it.
class Topic1VideoSection extends StatefulWidget {
  /// The videos currently saved on the topic.
  final List<Topic1Video> initialVideos;

  /// Saves the videos. Returns true when the write went through.
  final Future<bool> Function(List<Topic1Video> videos) onSave;

  const Topic1VideoSection({
    required this.initialVideos,
    required this.onSave,
    super.key,
  });

  @override
  State<Topic1VideoSection> createState() => _Topic1VideoSectionState();
}

class _Topic1VideoSectionState extends State<Topic1VideoSection> {
  /// The rows, in display order.
  final List<_VideoRow> _rows = [];

  /// Inline errors per row id: filled on a failed save, then refreshed on
  /// every change so each message clears as its field is fixed.
  final Map<String, Map<_VideoField, String>> _errors = {};

  /// True while the save is in flight.
  bool _isSaving = false;

  /// True when the rows differ from what is saved.
  bool _dirty = false;

  /// Ids of the rows whose fields are showing. Saved rows start folded;
  /// added rows, and rows that fail a save, unfold.
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _rows.addAll(widget.initialVideos.map(_VideoRow.fromVideo));
  }

  @override
  void dispose() {
    for (final _VideoRow row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  /// Every row's problems (rows without any are left out).
  Map<String, Map<_VideoField, String>> _validate() {
    final Map<String, Map<_VideoField, String>> errors = {};
    for (final _VideoRow row in _rows) {
      final Map<_VideoField, String> rowErrors = {};
      if (row.title.text.trim().isEmpty) {
        rowErrors[_VideoField.title] = "Give the video a title";
      }
      final String link = row.link.text.trim();
      if (link.isEmpty) {
        rowErrors[_VideoField.link] = "Paste the YouTube link";
      } else if (SubjectVideoLink.idOf(link) == null) {
        rowErrors[_VideoField.link] = "Not a YouTube video link";
      }
      if (row.type == null) {
        rowErrors[_VideoField.type] = "Choose whether it is free or paid";
      }
      if (rowErrors.isNotEmpty) errors[row.id] = rowErrors;
    }
    return errors;
  }

  /// Marks the rows changed and, once a save has failed, re-checks them.
  void _changed() {
    setState(() {
      _dirty = true;
      if (_errors.isNotEmpty) {
        _errors
          ..clear()
          ..addAll(_validate());
      }
    });
  }

  /// Validates, then saves the rows with their links normalised.
  Future<void> _save() async {
    final Map<String, Map<_VideoField, String>> errors = _validate();
    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
        _expanded.addAll(errors.keys);
      });
      Helper.showSnackBarMessage(
          msg: "Check the highlighted video fields", isSuccess: false);
      return;
    }

    final List<Topic1Video> videos = [
      for (final _VideoRow row in _rows)
        Topic1Video(
          id: row.id,
          title: row.title.text.trim(),
          link: SubjectVideoLink.normalize(row.link.text)!,
          type: row.type!,
        ),
    ];

    setState(() {
      _errors.clear();
      _isSaving = true;
    });
    final bool ok = await widget.onSave(videos);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (ok) {
        // Show the links as they were saved.
        for (int i = 0; i < _rows.length; i++) {
          _rows[i].link.text = videos[i].link;
        }
        _dirty = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Topic1SectionCard(
      icon: Icons.play_circle_outline,
      title: "Videos",
      count: _rows.length,
      emptyText: "No YouTube videos on this topic.",
      rows: [for (int i = 0; i < _rows.length; i++) _row(i)],
      addLabel: "Add a YouTube video",
      addKey: const Key('topic1_video_add'),
      onAdd: _isSaving
          ? null
          : () {
              final _VideoRow row = _VideoRow.fresh();
              _rows.add(row);
              _expanded.add(row.id);
              _changed();
            },
      saveKey: const Key('topic1_video_save'),
      isSaving: _isSaving,
      dirty: _dirty,
      onSave: _save,
    );
  }

  /// The line under a row's title: access, then the YouTube video ID.
  String _summary(_VideoRow row, String? videoId) {
    final String link;
    if (videoId != null) {
      link = "YouTube · $videoId";
    } else if (row.link.text.trim().isEmpty) {
      link = "No link";
    } else {
      link = "Not a YouTube link";
    }
    return "${topic1AccessLabel(row.type)} · $link";
  }

  /// One video: a header with its title and summary that folds the rest
  /// away; unfolded, title and access, then the link.
  Widget _row(int index) {
    final _VideoRow row = _rows[index];
    final Map<_VideoField, String> errors = _errors[row.id] ?? const {};
    final String? videoId = SubjectVideoLink.idOf(row.link.text);
    final bool expanded = _expanded.contains(row.id);

    return Padding(
      key: ValueKey(row.id),
      padding: const EdgeInsets.fromLTRB(18, 8, 12, 8),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Topic1RowHeader(
              index: index,
              title: row.title.text,
              untitledText: "Untitled video",
              summary: _summary(row, videoId),
              expanded: expanded,
              hasError: errors.isNotEmpty,
              toggleKey: Key('topic1_video_toggle_$index'),
              onToggle: () => setState(() {
                if (!_expanded.remove(row.id)) _expanded.add(row.id);
              }),
              removeKey: Key('topic1_video_remove_$index'),
              removeTooltip: "Remove this video",
              onRemove: _isSaving
                  ? null
                  : () {
                      _rows.removeAt(index).dispose();
                      _errors.remove(row.id);
                      _expanded.remove(row.id);
                      _changed();
                    },
            ),
            AnimatedSize(
              duration: topic1FoldDuration,
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: expanded
                  ? _fields(row, index, errors, videoId, constraints.maxWidth)
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  /// An unfolded row's fields.
  Widget _fields(_VideoRow row, int index, Map<_VideoField, String> errors,
      String? videoId, double width) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormTwoUp(
            width: width,
            breakpoint: 560,
            left: FormTextField(
              label: "Title",
              hint: "e.g. Newton's first law — explained",
              controller: row.title,
              fieldKey: Key('topic1_video_title_$index'),
              enabled: !_isSaving,
              error: errors[_VideoField.title],
              onChanged: _changed,
            ),
            right: FormAccessTypeField(
              types: topic1AccessTypes,
              selected: row.type,
              keyPrefix: "topic1_video_$index",
              error: errors[_VideoField.type],
              enabled: !_isSaving,
              onSelect: (type) {
                row.type = type;
                _changed();
              },
            ),
          ),
          const SizedBox(height: AppTokens.gapMd),
          FormTextField(
            label: "YouTube link",
            hint: "https://www.youtube.com/watch?v=…",
            controller: row.link,
            fieldKey: Key('topic1_video_link_$index'),
            enabled: !_isSaving,
            prefixIcon: Icons.link,
            error: errors[_VideoField.link],
            note: videoId == null ? null : "YouTube video · $videoId",
            onChanged: _changed,
          ),
        ],
      ),
    );
  }
}
