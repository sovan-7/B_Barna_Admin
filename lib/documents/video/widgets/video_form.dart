import 'package:bbarna/core/widgets/form/admin_form_scaffold.dart';
import 'package:bbarna/core/widgets/form/form_action_bar.dart';
import 'package:bbarna/core/widgets/form/form_fields.dart';
import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/documents/video/model/video_model.dart';
import 'package:bbarna/documents/video/viewModel/video_view_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/formatters.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The Add/Edit Video page. One responsive form serves both Add and Edit; the thin screens in
/// `screen/` just choose the mode ([existing] null means Add).
///
/// Sections: details (code, access, title, description) and the video link.
class VideoForm extends StatefulWidget {
  /// The item being edited; null means "Add".
  final VideoModel? existing;
  const VideoForm({this.existing, super.key});

  /// True when editing an existing item.
  bool get isEdit => existing != null;

  @override
  State<VideoForm> createState() => _VideoFormState();
}

/// The fields that can carry an inline error.
enum _Field { code, title, link, type }

class _VideoFormState extends State<VideoForm> {
  /// Text of the code field.
  final TextEditingController codeController = TextEditingController();

  /// Text of the title field.
  final TextEditingController titleController = TextEditingController();

  /// Text of the description field.
  final TextEditingController descriptionController = TextEditingController();

  /// Text of the video link field.
  final TextEditingController linkController = TextEditingController();

  /// Access types offered.
  static const List<String> videoTypeList = ["FREE", "PAID"];

  /// The chosen access type ("FREE" / "PAID").
  String? _selectedType;

  /// True while saving or deleting; disables every control.
  bool _isSaving = false;

  /// Inline error per field: filled on a failed submit, then refreshed on
  /// every change so each message clears as its field is fixed.
  final Map<_Field, String> _errors = <_Field, String>{};

  @override
  void initState() {
    super.initState();
    final VideoModel? existing = widget.existing;
    if (existing != null) {
      codeController.text = existing.code;
      titleController.text = existing.title;
      descriptionController.text =
          existing.description == stringDefault ? "" : existing.description;
      linkController.text = existing.link == stringDefault ? "" : existing.link;
      _selectedType = videoTypeList.contains(existing.videoType)
          ? existing.videoType
          : null;
    }
  }

  @override
  void dispose() {
    codeController.dispose();
    titleController.dispose();
    descriptionController.dispose();
    linkController.dispose();
    super.dispose();
  }

  /// Checks every field and returns the problems (empty when valid).
  Map<_Field, String> _validate() {
    final Map<_Field, String> errors = <_Field, String>{};
    if (codeController.text.trim().isEmpty) {
      errors[_Field.code] = "Give the video a code";
    }
    if (titleController.text.trim().isEmpty) {
      errors[_Field.title] = "Give the video a title";
    }

    final String link = linkController.text.trim();
    if (link.isEmpty) {
      errors[_Field.link] = "Add the video link";
    } else {
      // Nothing checked this before, so a typo saved a row the app could
      // never play.
      final Uri? uri = Uri.tryParse(link);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        errors[_Field.link] = "That does not look like a full URL";
      }
    }

    if ((_selectedType ?? "").isEmpty) {
      errors[_Field.type] = "Choose whether it is free or paid";
    }
    return errors;
  }

  /// Re-runs validation after an edit, but only once a submit has failed
  /// (so errors never appear while the form is still being filled in).
  void _revalidate() {
    if (_errors.isEmpty) return;
    final Map<_Field, String> fresh = _validate();
    setState(() {
      _errors
        ..clear()
        ..addAll(fresh);
    });
  }

  /// Validates, then creates or updates the item. Closes the page on
  /// success; on failure the view model has already shown why.
  Future<void> _onSubmit(VideoViewModel videoViewModel) async {
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

    final VideoModel model = VideoModel(
      codeController.text.trim().toUpperCase(),
      descriptionController.text.trim(),
      titleController.text.trim(),
      linkController.text.trim(),
      _selectedType ?? stringDefault,
      widget.existing?.timeStamp ?? DateTime.now().millisecondsSinceEpoch,
    );

    final bool success = widget.isEdit
        ? await videoViewModel.updateVideo(model, widget.existing!.docId)
        : await videoViewModel.addVideo(model);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Helper.showSnackBarMessage(
          msg: widget.isEdit
              ? "Video updated successfully"
              : "Video added successfully",
          isSuccess: true);
      Navigator.pop(context, true);
    }
  }

  /// Asks for confirmation, deletes the item and closes the page.
  void _onDelete(VideoViewModel videoViewModel) {
    final VideoModel existing = widget.existing!;
    RemoveAlert.showRemoveAlert(
      title: existing.title,
      description: "Are you sure want to delete ?",
      onPressYes: () async {
        Navigator.pop(navigatorKey.currentContext!);
        if (mounted) setState(() => _isSaving = true);
        final bool success = await videoViewModel.deleteVideo(existing.docId);
        if (!mounted) return;
        setState(() => _isSaving = false);
        if (success) {
          Helper.showInfoMessage(msg: "Video deleted successfully");
          Navigator.pop(context, true);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormScaffold(
      headerTitle: "Videos",
      sidebarIndex: 5,
      body: (context, width) => Consumer<VideoViewModel>(
        builder: (context, videoViewModel, child) =>
            _page(videoViewModel, width),
      ),
    );
  }

  /// The scrolling form (header and sections) with the action bar below.
  Widget _page(VideoViewModel videoViewModel, double width) {
    return FormPageBody(
      width: width,
      actionBar: _actionBar(videoViewModel, width),
      children: [
        _pageHeader(),
        const SizedBox(height: AppTokens.gapLg),
        FormSection(title: "VIDEO DETAILS", children: [
          FormTwoUp(
              width: width,
              left: _textField(
                label: "Video code",
                hint: "e.g. INTRO-01",
                controller: codeController,
                error: _errors[_Field.code],
                onChanged: _revalidate,
                uppercase: true,
              ),
              right: _typeField()),
          const SizedBox(height: AppTokens.gapMd),
          _textField(
            label: "Title",
            hint: "e.g. Introduction to Kinematics",
            controller: titleController,
            error: _errors[_Field.title],
            onChanged: _revalidate,
          ),
          const SizedBox(height: AppTokens.gapMd),
          _textField(
            label: "Description",
            hint: "What does this video cover? (optional)",
            controller: descriptionController,
            maxLines: 4,
          ),
        ]),
        const SizedBox(height: AppTokens.gapMd),
        FormSection(title: "LINK", children: [
          _textField(
            label: "Video link",
            hint: "https://www.youtube.com/watch?v=...",
            controller: linkController,
            error: _errors[_Field.link],
            onChanged: _revalidate,
            prefixIcon: Icons.link,
          ),
        ]),
        const SizedBox(height: AppTokens.gapXl),
      ],
    );
  }

  /// Back button, title and subtitle at the top of the page.
  Widget _pageHeader() {
    return FormPageHeader(
      title: widget.isEdit ? "Edit video" : "Add a video",
      subtitle: widget.isEdit
          ? "Update this video's details and link."
          : "Videos are linked, not uploaded.",
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
      types: videoTypeList,
      selected: _selectedType,
      keyPrefix: "video",
      error: _errors[_Field.type],
      enabled: !_isSaving,
      onSelect: (type) {
        setState(() => _selectedType = type);
        _revalidate();
      },
    );
  }

  /// Delete / Cancel / Save bar pinned to the bottom of the page.
  Widget _actionBar(VideoViewModel videoViewModel, double width) {
    return FormActionBar(
      width: width,
      isSaving: _isSaving,
      onDelete: widget.isEdit ? () => _onDelete(videoViewModel) : null,
      deleteTooltip: "Delete video",
      saveKey: const Key('video_save_button'),
      saveLabel: widget.isEdit ? "Update video" : "Save video",
      onSave: () => _onSubmit(videoViewModel),
      saveMinWidth: 135,
    );
  }
}
