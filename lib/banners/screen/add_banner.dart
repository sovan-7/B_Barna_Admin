import 'dart:typed_data';

import 'package:bbarna/banners/viewModel/banners_view_model.dart';
import 'package:bbarna/core/widgets/form/admin_form_scaffold.dart';
import 'package:bbarna/core/widgets/form/form_action_bar.dart';
import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/utils/formatters.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Upload a banner: a 16:9 drop area that previews the image the way the
/// app's carousel shows it, and a Save button that stays disabled until an
/// image is chosen.
class AddBanner extends StatefulWidget {
  const AddBanner({super.key});

  @override
  State<AddBanner> createState() => _AddBannerState();
}

class _AddBannerState extends State<AddBanner> {
  /// The picked image, not uploaded yet.
  Uint8List? selectedImageBytes;

  /// File name of the picked image.
  String imageName = "";

  /// True while uploading; disables every control.
  bool _isSaving = false;

  /// Shown when Save is pressed with no image chosen.
  String? _error;

  /// Opens the file picker for an image.
  Future<void> _pickImage() async {
    final FilePickerResult? picked =
        await FilePicker.platform.pickFiles(type: FileType.image);
    if (picked == null || !mounted) return;

    setState(() {
      selectedImageBytes = picked.files.first.bytes;
      imageName = picked.files.first.name;
      _error = null;
    });
  }

  /// Uploads the banner and closes the page on success.
  Future<void> _onSave(BannersViewModel bannersViewModel) async {
    final Uint8List? image = selectedImageBytes;
    if (image == null) {
      // No image chosen: say so on the page.
      setState(() => _error = "Choose an image to upload");
      return;
    }

    setState(() {
      _error = null;
      _isSaving = true;
    });

    final bool success = await bannersViewModel.createBanner(image);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Helper.showSnackBarMessage(
          msg: "Banner uploaded successfully", isSuccess: true);
      Navigator.pop(context, true);
    }
    // On failure the view model has already said so, and the page stays put
    // with the chosen image still in place to retry.
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormScaffold(
      headerTitle: "Banners",
      sidebarIndex: 0,
      body: (context, width) => Consumer<BannersViewModel>(
        builder: (context, bannersViewModel, child) =>
            _page(bannersViewModel, width),
      ),
    );
  }

  /// Header and the upload card, with the action bar below.
  Widget _page(BannersViewModel bannersViewModel, double width) {
    return FormPageBody(
      width: width,
      maxWidth: 640,
      actionBar: _actionBar(bannersViewModel, width),
      children: [
        _pageHeader(),
        const SizedBox(height: AppTokens.gapLg),
        _card(),
      ],
    );
  }

  /// Back button, title and subtitle at the top of the page.
  Widget _pageHeader() {
    return FormPageHeader(
      title: "Add a banner",
      subtitle: "It appears on the app's home screen carousel.",
      onBack: _isSaving ? null : () => Navigator.pop(context),
    );
  }

  /// The upload card: drop area, file row and error.
  Widget _card() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppTokens.hairline),
        boxShadow: AppTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("BANNER IMAGE", style: AppTokens.sectionTitle),
          const SizedBox(height: AppTokens.gapMd),
          _dropArea(),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: AppTokens.errorText),
          ],
          if (selectedImageBytes != null) ...[
            const SizedBox(height: AppTokens.gapMd),
            _fileRow(),
          ],
        ],
      ),
    );
  }

  /// A 16:9 well — the shape the banner is shown at — so the preview matches
  /// what the carousel shows.
  Widget _dropArea() {
    final bool hasImage = selectedImageBytes != null;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Material(
        color: hasImage ? AppTokens.surface : AppTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: InkWell(
          onTap: _isSaving ? null : _pickImage,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(
                color: _error != null
                    ? AppTokens.danger
                    : hasImage
                        ? AppTokens.hairline
                        : AppTokens.inkFaint.withValues(alpha: .55),
                width: hasImage ? 1 : 1.4,
              ),
            ),
            child: hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd - 1),
                    child: Image.memory(selectedImageBytes!,
                        fit: BoxFit.cover, width: double.infinity),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 32, color: AppTokens.inkFaint),
                      SizedBox(height: 10),
                      Text("Choose an image",
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppTokens.ink)),
                      SizedBox(height: 4),
                      Text("Wide images work best — around 16:9.",
                          style: TextStyle(
                              fontSize: 12, color: AppTokens.inkFaint)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// Picked file name and size, with Replace / Remove.
  Widget _fileRow() {
    final int bytes = selectedImageBytes!.lengthInBytes;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: AppTokens.hairline),
      ),
      child: Row(
        children: [
          const Icon(Icons.image_outlined, size: 16, color: AppTokens.inkMuted),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  imageName.isEmpty ? "Selected image" : imageName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.ink),
                ),
                Text(readableFileSize(bytes),
                    style: const TextStyle(
                        fontSize: 11.5, color: AppTokens.inkFaint)),
              ],
            ),
          ),
          TextButton(
            onPressed: _isSaving ? null : _pickImage,
            style: TextButton.styleFrom(
                foregroundColor: AppTokens.inkMuted,
                padding: const EdgeInsets.symmetric(horizontal: 10)),
            child: const Text("Replace", style: TextStyle(fontSize: 12.5)),
          ),
          TextButton(
            onPressed: _isSaving
                ? null
                : () => setState(() {
                      selectedImageBytes = null;
                      imageName = "";
                    }),
            style: TextButton.styleFrom(
                foregroundColor: AppTokens.danger,
                padding: const EdgeInsets.symmetric(horizontal: 10)),
            child: const Text("Remove", style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  /// Cancel / Upload bar pinned to the bottom of the page.
  Widget _actionBar(BannersViewModel bannersViewModel, double width) {
    return FormActionBar(
      width: width,
      isSaving: _isSaving,
      saveKey: const Key('banner_save_button'),
      saveLabel: "Upload banner",
      onSave: () => _onSave(bannersViewModel),
      maxWidth: 640,
    );
  }
}
