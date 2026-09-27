import 'dart:typed_data';

import 'package:bbarna/banners/viewModel/banners_view_model.dart';
import 'package:bbarna/core/widgets/app_header.dart';
import 'package:bbarna/core/widgets/sidebar.dart';
import 'package:bbarna/resources/app_tokens.dart';
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
  final GlobalKey<ScaffoldState> key = GlobalKey();

  Uint8List? selectedImageBytes;
  String imageName = "";
  bool _isSaving = false;
  String? _error;

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
      Navigator.pop(context);
    }
    // On failure the view model has already said so, and the page stays put
    // with the chosen image still in place to retry.
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isCompact = width < AppTokens.compactBreakpoint;

    return Scaffold(
      key: key,
      backgroundColor: AppTokens.canvas,
      body: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
        },
        child: Column(children: [
          AppHeader(
            onTapIcon: () => key.currentState?.openDrawer(),
            title: "Banners",
          ),
          Expanded(
            child: Row(children: [
              if (!isCompact)
                const Expanded(child: ExtraSideBar(sidebarIndex: 0)),
              Expanded(
                flex: 5,
                child: Consumer<BannersViewModel>(
                  builder: (context, bannersViewModel, child) =>
                      _page(bannersViewModel, width),
                ),
              ),
            ]),
          ),
        ]),
      ),
      drawer:
          isCompact ? const Drawer(child: ExtraSideBar(sidebarIndex: 0)) : null,
    );
  }

  Widget _page(BannersViewModel bannersViewModel, double width) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
                horizontal: width < 700 ? 16 : 32, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _pageHeader(),
                    const SizedBox(height: AppTokens.gapLg),
                    _card(),
                  ],
                ),
              ),
            ),
          ),
        ),
        _actionBar(bannersViewModel, width),
      ],
    );
  }

  Widget _pageHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _backButton(),
        const SizedBox(width: AppTokens.gapMd),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Add a banner", style: AppTokens.pageTitle),
              SizedBox(height: 3),
              Text("It appears on the app's home screen carousel.",
                  style: AppTokens.pageSubtitle),
            ],
          ),
        ),
      ],
    );
  }

  Widget _backButton() {
    return Material(
      color: AppTokens.surface,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: InkWell(
        onTap: _isSaving ? null : () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(color: AppTokens.hairline),
          ),
          child: const Icon(Icons.arrow_back, size: 18, color: AppTokens.ink),
        ),
      ),
    );
  }

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
                Text(_readableSize(bytes),
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

  static String _readableSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(0)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  Widget _actionBar(BannersViewModel bannersViewModel, double width) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: width < 700 ? 16 : 32, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTokens.surface,
        border: Border(top: BorderSide(color: AppTokens.hairline)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Row(
            children: [
              // Below ~560px the two buttons stop fitting side by side, so
              // Save takes the remaining width — the usual mobile shape,
              // and it keeps Save the biggest target on the bar.
              if (width >= 560) const Spacer(),
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppTokens.inkMuted,
                  padding: EdgeInsets.symmetric(
                      horizontal: width < 560 ? 12 : 18, vertical: 14),
                ),
                child: const Text("Cancel"),
              ),
              const SizedBox(width: AppTokens.gapSm),
              _saveButton(bannersViewModel, expand: width < 560),
            ],
          ),
        ),
      ),
    );
  }

  Widget _saveButton(BannersViewModel bannersViewModel,
      {required bool expand}) {
    final Widget button = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, minHeight: 42),
      child: ElevatedButton(
        key: const Key('banner_save_button'),
        onPressed: _isSaving ? null : () => _onSave(bannersViewModel),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.ink,
          disabledBackgroundColor: AppTokens.ink.withValues(alpha: .55),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
        ),
        child: _isSaving
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: Colors.white),
              )
            : const Text("Upload banner",
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
      ),
    );

    return expand ? Expanded(child: button) : button;
  }
}
