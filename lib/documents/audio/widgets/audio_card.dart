import 'package:bbarna/core/widgets/card/admin_card_shell.dart';
import 'package:bbarna/core/widgets/card/card_actions.dart';
import 'package:bbarna/core/widgets/card/card_chips.dart';
import 'package:bbarna/core/widgets/card/card_helpers.dart';
import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/documents/audio/model/audio_model.dart';
import 'package:bbarna/documents/audio/screen/edit_audio.dart';
import 'package:bbarna/documents/audio/viewModel/audio_view_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/navigation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// One row of the audio list: icon, title, code, description and a
/// "Play the file" link; FREE/PAID chip; edit / delete buttons.
class AudioCard extends StatefulWidget {
  /// The item shown in this row.
  final AudioModel audioData;

  /// Called after an edit or delete so the list can reload.
  final VoidCallback onChanged;

  const AudioCard(
      {required this.audioData, required this.onChanged, super.key});

  @override
  State<AudioCard> createState() => _AudioCardState();
}

class _AudioCardState extends State<AudioCard> {
  /// Shortcut for the item shown.
  AudioModel get _data => widget.audioData;

  @override
  Widget build(BuildContext context) {
    return AdminCardShell(
      builder: (context, layout) {
        final bool isCompact = layout.isCompact;
        final bool showActions = layout.showActions;
        return isCompact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _identity(),
                  const SizedBox(height: 10),
                  Row(children: [
                    _chips(),
                    const Spacer(),
                    _actions(showActions),
                  ]),
                ],
              )
            : Row(
                children: [
                  Expanded(child: _identity()),
                  const SizedBox(width: AppTokens.gapMd),
                  _chips(),
                  const SizedBox(width: AppTokens.gapSm),
                  _actions(showActions),
                ],
              );
      },
    );
  }

  /// Left part of the row: picture or icon, name, code and details.
  Widget _identity() {
    final bool hasDescription = _data.description.trim().isNotEmpty &&
        _data.description != stringDefault;
    final bool hasFile =
        _data.link.trim().isNotEmpty && _data.link != stringDefault;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: AppTokens.surfaceMuted,
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            border: Border.all(color: AppTokens.hairline),
          ),
          child: Icon(Icons.headphones_outlined,
              size: 20,
              color: hasFile ? AppTokens.accentInk : AppTokens.inkFaint),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: SelectableLabel(
                      _data.title,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppTokens.ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CodeChip(_data.code),
                ],
              ),
              if (hasDescription) ...[
                const SizedBox(height: 4),
                Text(_data.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTokens.body),
              ],
              const SizedBox(height: 6),
              // An explicit link to the file, or a warning when there is
              // none.
              if (hasFile)
                Row(
                  children: [
                    const Icon(Icons.attach_file,
                        size: 13, color: AppTokens.inkFaint),
                    const SizedBox(width: 5),
                    InkWell(
                      key: Key('audio_open_${_data.docId}'),
                      onTap: () => openExternalUrl(_data.link,
                          failureMessage: "Could not open that clip"),
                      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Text("Play the file",
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTokens.accentInk)),
                            SizedBox(width: 4),
                            Icon(Icons.open_in_new,
                                size: 12, color: AppTokens.accentInk),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              else
                const Text("No file uploaded",
                    style: TextStyle(fontSize: 11.5, color: AppTokens.danger)),
            ],
          ),
        ),
      ],
    );
  }

  /// Status chips shown beside (or, when compact, under) the identity.
  Widget _chips() {
    final bool isFree = _data.audioType.toUpperCase() == "FREE";
    final Color typeColor = isFree ? AppTokens.accentInk : AppTokens.accentInk;

    return StatusChip(
      icon: isFree ? Icons.lock_open_outlined : Icons.paid_outlined,
      label: _data.audioType.isEmpty || _data.audioType == stringDefault
          ? "No type"
          : _data.audioType.toUpperCase(),
      color: typeColor,
      filled: true,
    );
  }

  /// Row buttons; faded in on hover, always shown on compact screens.
  Widget _actions(bool visible) =>
      audioActions(context, _data, widget.onChanged, visible);
}

/// Row buttons for [data], shared by the card and the table row (same
/// keys); faded in on hover, always shown on compact screens.
Widget audioActions(BuildContext context, AudioModel data,
    VoidCallback onChanged, bool visible) {
  return CardActions(
    visible: visible,
    buttons: [
      CardEditButton(
        buttonKey: Key('audio_edit_${data.docId}'),
        tooltip: "Edit audio",
        onTap: () => openEditAudio(context, data, onChanged),
      ),
      CardDeleteButton(
        buttonKey: Key('audio_delete_${data.docId}'),
        tooltip: "Delete audio",
        onTap: () => confirmDeleteAudio(context, data, onChanged),
      ),
    ],
  );
}

/// Opens the edit screen; the list reloads if it saved or deleted
/// something.
void openEditAudio(
    BuildContext context, AudioModel data, VoidCallback onChanged) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => EditAudio(audioData: data)),
  ).ifSaved(onChanged);
}

/// Asks for confirmation, then deletes this item.
void confirmDeleteAudio(
    BuildContext context, AudioModel data, VoidCallback onChanged) {
  final AudioViewModel audioViewModel =
      Provider.of<AudioViewModel>(context, listen: false);
  final String docId = data.docId;

  confirmDelete(
    title: data.title,
    delete: () => audioViewModel.deleteAudio(docId),
    successMessage: "Audio deleted successfully",
  );
}
