import 'package:bbarna/core/widgets/form/admin_form_scaffold.dart';
import 'package:bbarna/core/widgets/form/form_action_bar.dart';
import 'package:bbarna/core/widgets/form/form_fields.dart';
import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/documents/audio/model/audio_model.dart';
import 'package:bbarna/documents/audio/viewModel/audio_view_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/formatters.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// The whole Add/Edit Audio page. [existing] null means Add.
///
/// Add and Edit were two 281 and 297 line screens holding the same form
/// twice over. There is one responsive form here, and the two screens in
/// `screen/` just choose the mode.
class AudioForm extends StatefulWidget {
  final AudioModel? existing;
  const AudioForm({this.existing, super.key});

  bool get isEdit => existing != null;

  @override
  State<AudioForm> createState() => _AudioFormState();
}

enum _Field { code, title, file, type }

class _AudioFormState extends State<AudioForm> {
  final TextEditingController codeController = TextEditingController();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  Uint8List? selectedAudioBytes;
  String audioName = "";

  static const List<String> audioTypeList = ["FREE", "PAID"];
  String? _selectedType;
  bool _isSaving = false;

  final Map<_Field, String> _errors = <_Field, String>{};

  @override
  void initState() {
    super.initState();
    final AudioModel? existing = widget.existing;
    if (existing != null) {
      codeController.text = existing.code;
      titleController.text = existing.title;
      descriptionController.text =
          existing.description == stringDefault ? "" : existing.description;
      _selectedType = audioTypeList.contains(existing.audioType)
          ? existing.audioType
          : null;
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Map<_Field, String> _validate() {
    final Map<_Field, String> errors = <_Field, String>{};
    if (codeController.text.trim().isEmpty) {
      errors[_Field.code] = "Give the clip a code";
    }
    if (titleController.text.trim().isEmpty) {
      errors[_Field.title] = "Give the clip a title";
    }

    // A file is only mandatory when creating: an edit keeps the one the
    // document already has.
    if (!widget.isEdit && selectedAudioBytes == null) {
      errors[_Field.file] = "Choose an audio file to upload";
    }

    if ((_selectedType ?? "").isEmpty) {
      errors[_Field.type] = "Choose whether it is free or paid";
    }
    return errors;
  }

  void _revalidate() {
    if (_errors.isEmpty) return;
    final Map<_Field, String> fresh = _validate();
    setState(() {
      _errors
        ..clear()
        ..addAll(fresh);
    });
  }

  Future<void> _onSubmit(AudioViewModel audioViewModel) async {
    final Map<_Field, String> errors = _validate();
    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
      });
      Helper.showSnackBarMessage(
          msg: errors.length == 1
              ? "Check the highlighted field"
              : "Check the ${errors.length} highlighted fields",
          isSuccess: false);
      return;
    }

    setState(() {
      _errors.clear();
      _isSaving = true;
    });

    final AudioModel model = AudioModel(
      codeController.text.trim().toUpperCase(),
      descriptionController.text.trim(),
      titleController.text.trim(),
      widget.existing?.link ?? "",
      _selectedType ?? stringDefault,
      widget.existing?.timeStamp ?? DateTime.now().millisecondsSinceEpoch,
    );

    final bool success = widget.isEdit
        ? await audioViewModel.updateAudio(model, widget.existing!.docId,
            file: selectedAudioBytes)
        : await audioViewModel.createAudio(model, selectedAudioBytes!);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Helper.showSnackBarMessage(
          msg: widget.isEdit
              ? "Audio updated successfully"
              : "Audio added successfully",
          isSuccess: true);
      Navigator.pop(context);
    }
  }

  void _onDelete(AudioViewModel audioViewModel) {
    final AudioModel existing = widget.existing!;
    RemoveAlert.showRemoveAlert(
      title: existing.title,
      description: "Are you sure want to delete ?",
      onPressYes: () async {
        Navigator.pop(navigatorKey.currentContext!);
        if (mounted) setState(() => _isSaving = true);
        final bool success = await audioViewModel.deleteAudio(existing.docId);
        if (!mounted) return;
        setState(() => _isSaving = false);
        if (success) {
          Helper.showInfoMessage(msg: "Audio deleted successfully");
          Navigator.pop(context);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormScaffold(
      headerTitle: "Audio",
      sidebarIndex: 7,
      body: (context, width) => Consumer<AudioViewModel>(
        builder: (context, audioViewModel, child) =>
            _page(audioViewModel, width),
      ),
    );
  }

  Widget _page(AudioViewModel audioViewModel, double width) {
    return FormPageBody(
      width: width,
      actionBar: _actionBar(audioViewModel, width),
      children: [
        _pageHeader(),
        const SizedBox(height: AppTokens.gapLg),
        FormSection(title: "AUDIO DETAILS", children: [
          FormTwoUp(
              width: width,
              left: _textField(
                label: "Audio code",
                hint: "e.g. LECTURE-01",
                controller: codeController,
                error: _errors[_Field.code],
                onChanged: _revalidate,
                uppercase: true,
              ),
              right: _typeField()),
          const SizedBox(height: AppTokens.gapMd),
          _textField(
            label: "Title",
            hint: "e.g. Kinematics — recorded lecture",
            controller: titleController,
            error: _errors[_Field.title],
            onChanged: _revalidate,
          ),
          const SizedBox(height: AppTokens.gapMd),
          _textField(
            label: "Description",
            hint: "What does this clip cover? (optional)",
            controller: descriptionController,
            maxLines: 4,
          ),
        ]),
        const SizedBox(height: AppTokens.gapMd),
        FormSection(title: "FILE", children: [_fileField()]),
        const SizedBox(height: AppTokens.gapXl),
      ],
    );
  }

  /// Back button, title and subtitle at the top of the page.
  Widget _pageHeader() {
    return FormPageHeader(
      title: widget.isEdit ? "Edit audio" : "Add a clip",
      subtitle: widget.isEdit
          ? "Update this clip's details and file."
          : "Upload a clip for students to play in the app.",
      onBack: _isSaving ? null : () => Navigator.pop(context),
    );
  }

  /// A [FormTextField] configured for this form.
  Widget _textField({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
    String? error,
    VoidCallback? onChanged,
    bool uppercase = false,
    IconData? prefixIcon,
  }) {
    return FormTextField(
      label: label,
      hint: hint,
      controller: controller,
      maxLines: maxLines,
      error: error,
      onChanged: onChanged,
      prefixIcon: prefixIcon,
      inputFormatters: [if (uppercase) UpperCaseTextFormatter()],
    );
  }

  /// FREE / PAID as two segments.
  Widget _typeField() {
    return FormAccessTypeField(
      types: audioTypeList,
      selected: _selectedType,
      keyPrefix: "audio",
      error: _errors[_Field.type],
      enabled: !_isSaving,
      onSelect: (type) {
        setState(() => _selectedType = type);
        _revalidate();
      },
    );
  }

  Future<void> _pickFile() async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'aac'],
    );
    if (picked == null || !mounted) return;
    setState(() {
      selectedAudioBytes = picked.files.first.bytes;
      audioName = picked.files.first.name;
    });
    _revalidate();
  }

  /// The old picker was a grey "Choose Pdf" chip with the file name in
  /// plain text beside it, and no way to tell whether an edit already had
  /// a file attached.
  Widget _fileField() {
    final String? error = _errors[_Field.file];
    final bool hasNew = selectedAudioBytes != null;
    final bool hasExisting = (widget.existing?.link ?? "").trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: hasNew ? AppTokens.surface : AppTokens.surfaceMuted,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          child: InkWell(
            key: const Key('audio_choose_file'),
            onTap: _isSaving ? null : _pickFile,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 26),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                border: Border.all(
                  color: error != null
                      ? AppTokens.danger
                      : AppTokens.inkFaint.withValues(alpha: .5),
                  width: 1.4,
                ),
              ),
              child: Column(
                children: [
                  Icon(hasNew ? Icons.audio_file : Icons.upload_file_outlined,
                      size: 30,
                      color: hasNew
                          ? const Color(0xFFD92D20)
                          : AppTokens.inkFaint),
                  const SizedBox(height: 10),
                  Text(
                    hasNew
                        ? (audioName.isEmpty ? "Selected file" : audioName)
                        : hasExisting
                            ? "Replace the current file"
                            : "Choose an audio file",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppTokens.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasNew
                        ? readableFileSize(selectedAudioBytes!.lengthInBytes)
                        : hasExisting
                            ? "A file is already attached — leave this to keep it."
                            : "MP3 or M4A.",
                    style: const TextStyle(
                        fontSize: 12, color: AppTokens.inkFaint),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasNew) ...[
          const SizedBox(height: AppTokens.gapSm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isSaving
                  ? null
                  : () => setState(() {
                        selectedAudioBytes = null;
                        audioName = "";
                      }),
              style: TextButton.styleFrom(
                  foregroundColor: AppTokens.danger,
                  padding: const EdgeInsets.symmetric(horizontal: 10)),
              child: const Text("Remove", style: TextStyle(fontSize: 12.5)),
            ),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(error, style: AppTokens.errorText),
        ],
      ],
    );
  }

  /// Delete / Cancel / Save bar pinned to the bottom of the page.
  Widget _actionBar(AudioViewModel audioViewModel, double width) {
    return FormActionBar(
      width: width,
      isSaving: _isSaving,
      onDelete: widget.isEdit ? () => _onDelete(audioViewModel) : null,
      deleteTooltip: "Delete audio",
      saveKey: const Key('audio_save_button'),
      saveLabel: widget.isEdit ? "Update clip" : "Save clip",
      onSave: () => _onSubmit(audioViewModel),
      saveMinWidth: 135,
    );
  }
}
