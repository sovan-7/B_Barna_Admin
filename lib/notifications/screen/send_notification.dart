import 'package:bbarna/banners/model/banners_model.dart';
import 'package:bbarna/banners/viewModel/banners_view_model.dart';
import 'package:bbarna/core/widgets/form/admin_form_scaffold.dart';
import 'package:bbarna/core/widgets/form/form_action_bar.dart';
import 'package:bbarna/core/widgets/form/form_fields.dart';
import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/notifications/viewModel/notifications_view_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Where the notification's picture comes from.
enum NotificationImageSource {
  /// Text only.
  none,

  /// A new picture picked from this computer.
  upload,

  /// One of the home-carousel banners.
  banner,
}

/// Compose a push notification for every app user: a title, an optional
/// message, an optional picture (uploaded, or one of the banners), and a
/// preview of how it shows on a phone. Sending asks for confirmation first,
/// since it can't be taken back.
class SendNotification extends StatefulWidget {
  const SendNotification({super.key});

  /// Longest title that still fits on one line of most phones.
  static const int titleMaxLength = 65;

  /// Longest message a phone shows before cutting it off.
  static const int bodyMaxLength = 240;

  @override
  State<SendNotification> createState() => _SendNotificationState();
}

class _SendNotificationState extends State<SendNotification> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  NotificationImageSource _imageSource = NotificationImageSource.none;

  /// The picked picture (upload), not uploaded yet.
  Uint8List? _imageBytes;

  /// File name of [_imageBytes].
  String _imageName = "";

  /// URL of the chosen banner (banner).
  String? _bannerUrl;

  /// True while sending; disables every control.
  bool _isSending = false;

  /// Shown under the title when Send is pressed without one.
  String? _titleError;

  /// Shown under the picture when the chosen source has nothing picked.
  String? _imageError;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  /// Opens the file picker for a picture.
  Future<void> _pickImage() async {
    final FilePickerResult? picked =
        await FilePicker.platform.pickFiles(type: FileType.image);
    if (picked == null || !mounted) return;

    setState(() {
      _imageBytes = picked.files.first.bytes;
      _imageName = picked.files.first.name;
      _imageError = null;
    });
  }

  /// Switches the picture source; loads the banners the first time they're
  /// needed.
  void _selectSource(NotificationImageSource source) {
    setState(() {
      _imageSource = source;
      _imageError = null;
    });
    if (source == NotificationImageSource.banner) {
      final BannersViewModel banners =
          Provider.of<BannersViewModel>(context, listen: false);
      if (banners.bannersList.isEmpty) banners.getBannerList();
    }
  }

  /// The picture that goes out with the notification, as a URL (banner) —
  /// a new upload is previewed from [_imageBytes] instead.
  String? get _chosenUrl =>
      _imageSource == NotificationImageSource.banner ? _bannerUrl : null;

  /// The new picture to upload, if that's the chosen source.
  Uint8List? get _chosenBytes =>
      _imageSource == NotificationImageSource.upload ? _imageBytes : null;

  /// Checks the form; sets the error texts and returns whether it's valid.
  bool _validate() {
    String? titleError;
    String? imageError;
    if (_titleController.text.trim().isEmpty) {
      titleError = "Enter a title";
    }
    if (_imageSource == NotificationImageSource.upload && _imageBytes == null) {
      imageError = "Choose a picture, or pick \"No picture\"";
    }
    if (_imageSource == NotificationImageSource.banner && _bannerUrl == null) {
      imageError = "Choose a banner, or pick \"No picture\"";
    }
    setState(() {
      _titleError = titleError;
      _imageError = imageError;
    });
    return titleError == null && imageError == null;
  }

  /// Validates, asks "send to everyone?", then sends and closes the page.
  void _onSend(NotificationsViewModel vm) {
    if (!_validate()) return;

    RemoveAlert.showRemoveAlert(
      title: _titleController.text.trim(),
      description: "This goes to every app user's phone right away "
          "and can't be taken back.",
      confirmLabel: "Send",
      onPressYes: () async {
        Navigator.pop(navigatorKey.currentContext!);
        await _send(vm);
      },
    );
  }

  Future<void> _send(NotificationsViewModel vm) async {
    setState(() => _isSending = true);

    final bool success = await vm.sendNotification(
      title: _titleController.text,
      body: _bodyController.text,
      newImage: _chosenBytes,
      existingImageUrl: _chosenUrl,
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (success) {
      Helper.showSnackBarMessage(
          msg: "Notification is on its way", isSuccess: true);
      Navigator.pop(context, true);
    }
    // On failure the view model has already said so, and the page stays put
    // with everything still filled in to retry.
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormScaffold(
      headerTitle: "Notifications",
      sidebarIndex: notificationModuleIndex,
      body: (context, width) => Consumer<NotificationsViewModel>(
        builder: (context, vm, child) => FormPageBody(
          width: width,
          maxWidth: 720,
          actionBar: FormActionBar(
            width: width,
            isSaving: _isSending,
            saveKey: const Key('notification_send_button'),
            saveLabel: "Send to all users",
            onSave: () => _onSend(vm),
            maxWidth: 720,
          ),
          children: [
            FormPageHeader(
              title: "Send a notification",
              subtitle: "It goes to every app user's phone.",
              onBack: _isSending ? null : () => Navigator.pop(context),
            ),
            const SizedBox(height: AppTokens.gapLg),
            _messageSection(),
            const SizedBox(height: AppTokens.gapMd),
            _pictureSection(),
            const SizedBox(height: AppTokens.gapMd),
            FormSection(
              title: "PREVIEW",
              children: [
                NotificationPreview(
                  title: _titleController.text,
                  body: _bodyController.text,
                  imageBytes: _chosenBytes,
                  imageUrl: _chosenUrl,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Title and message.
  Widget _messageSection() {
    return FormSection(
      title: "MESSAGE",
      children: [
        FormTextField(
          fieldKey: const Key('notification_title_field'),
          label: "Title",
          hint: "e.g. New batch starts Monday",
          controller: _titleController,
          enabled: !_isSending,
          error: _titleError,
          note: "${_titleController.text.length}"
              "/${SendNotification.titleMaxLength}",
          inputFormatters: [
            LengthLimitingTextInputFormatter(SendNotification.titleMaxLength),
          ],
          onChanged: () => setState(() => _titleError = null),
        ),
        const SizedBox(height: AppTokens.gapMd),
        FormTextField(
          fieldKey: const Key('notification_body_field'),
          label: "Message (optional)",
          hint: "e.g. Join the live class at 7 pm.",
          controller: _bodyController,
          enabled: !_isSending,
          maxLines: 4,
          note: "${_bodyController.text.length}"
              "/${SendNotification.bodyMaxLength}",
          inputFormatters: [
            LengthLimitingTextInputFormatter(SendNotification.bodyMaxLength),
          ],
          onChanged: () => setState(() {}),
        ),
      ],
    );
  }

  /// No picture / upload one / use a banner.
  Widget _pictureSection() {
    return FormSection(
      title: "PICTURE",
      children: [
        Wrap(
          spacing: AppTokens.gapSm,
          runSpacing: AppTokens.gapSm,
          children: [
            _sourceChip(NotificationImageSource.none, "No picture",
                Icons.notes_outlined),
            _sourceChip(NotificationImageSource.upload, "Upload a picture",
                Icons.upload_outlined),
            _sourceChip(NotificationImageSource.banner, "Use a banner",
                Icons.image_outlined),
          ],
        ),
        if (_imageSource == NotificationImageSource.upload) ...[
          const SizedBox(height: AppTokens.gapMd),
          FormImagePickerField(
            bytes: _imageBytes,
            fileName: _imageName,
            existingUrl: "",
            error: _imageError,
            enabled: !_isSending,
            onPick: _pickImage,
            onRemove: () => setState(() {
              _imageBytes = null;
              _imageName = "";
            }),
          ),
        ],
        if (_imageSource == NotificationImageSource.banner) ...[
          const SizedBox(height: AppTokens.gapMd),
          _bannerPicker(),
          if (_imageError != null) FieldErrorText(_imageError!),
        ],
        if (_imageSource == NotificationImageSource.upload &&
            _imageError == null) ...[
          const SizedBox(height: AppTokens.gapSm),
          const Text(
            "Wide pictures (2:1) show best. Very large ones are shrunk.",
            style: TextStyle(fontSize: 11.5, color: AppTokens.inkFaint),
          ),
        ],
      ],
    );
  }

  Widget _sourceChip(
      NotificationImageSource source, String label, IconData icon) {
    final bool selected = _imageSource == source;
    return ChoiceChip(
      key: Key('notification_source_${source.name}'),
      avatar: Icon(icon,
          size: 16, color: selected ? AppTokens.surface : AppTokens.inkMuted),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppTokens.ink,
      backgroundColor: AppTokens.surfaceMuted,
      labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: selected ? AppTokens.surface : AppTokens.ink),
      side: const BorderSide(color: AppTokens.hairline),
      onSelected: _isSending ? null : (_) => _selectSource(source),
    );
  }

  /// The banners as small tiles; tapping one chooses it.
  Widget _bannerPicker() {
    return Consumer<BannersViewModel>(builder: (context, banners, child) {
      if (banners.isLoading) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: AppTokens.gapMd),
          child: Center(
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))),
        );
      }
      final String? loadError = banners.loadError;
      if (banners.bannersList.isEmpty && loadError != null) {
        return LoadErrorLine(
            message: loadError, onRetry: banners.getBannerList);
      }
      final List<BannersModel> usable = banners.bannersList
          .where((b) => b.bannerImage.startsWith("http"))
          .toList();
      if (usable.isEmpty) {
        return const Text("There are no banners yet.",
            style: TextStyle(fontSize: 12.5, color: AppTokens.inkMuted));
      }
      return Wrap(
        spacing: AppTokens.gapSm,
        runSpacing: AppTokens.gapSm,
        children: [
          for (final BannersModel banner in usable)
            _bannerTile(banner.bannerImage),
        ],
      );
    });
  }

  Widget _bannerTile(String url) {
    final bool selected = _bannerUrl == url;
    return InkWell(
      onTap: _isSending
          ? null
          : () => setState(() {
                _bannerUrl = url;
                _imageError = null;
              }),
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: Container(
        width: 160,
        height: 90,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          border: Border.all(
              color: selected ? AppTokens.ink : AppTokens.hairline,
              width: selected ? 2.5 : 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm - 1),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => const Center(
                child: Icon(Icons.broken_image_outlined,
                    color: AppTokens.inkFaint)),
          ),
        ),
      ),
    );
  }
}

/// Roughly how the notification looks when pulled open on an Android
/// phone: app name, title, message and the big picture.
class NotificationPreview extends StatelessWidget {
  /// Title as typed; a grey placeholder shows while it's empty.
  final String title;

  /// Message as typed; hidden while empty.
  final String body;

  /// A newly picked picture (shown in preference to [imageUrl]).
  final Uint8List? imageBytes;

  /// An already uploaded picture, e.g. a banner.
  final String? imageUrl;

  const NotificationPreview({
    required this.title,
    required this.body,
    this.imageBytes,
    this.imageUrl,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final Uint8List? bytes = imageBytes;
    final String? url = imageUrl;
    final String shownTitle = title.trim().isEmpty ? "Title" : title.trim();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          padding: const EdgeInsets.all(AppTokens.gapMd),
          decoration: BoxDecoration(
            color: AppTokens.surfaceMuted,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTokens.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.school, size: 14, color: AppTokens.inkMuted),
                  SizedBox(width: 6),
                  Text("B Barna · now",
                      style:
                          TextStyle(fontSize: 11.5, color: AppTokens.inkMuted)),
                ],
              ),
              const SizedBox(height: AppTokens.gapSm),
              Text(
                shownTitle,
                key: const Key('notification_preview_title'),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: title.trim().isEmpty
                        ? AppTokens.inkFaint
                        : AppTokens.ink),
              ),
              if (body.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(body.trim(),
                    style: const TextStyle(
                        fontSize: 13, height: 1.35, color: AppTokens.inkMuted)),
              ],
              if (bytes != null || url != null) ...[
                const SizedBox(height: AppTokens.gapSm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                  child: AspectRatio(
                    aspectRatio: 2 / 1,
                    child: bytes != null
                        ? Image.memory(bytes, fit: BoxFit.cover)
                        : Image.network(url!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) =>
                                const ColoredBox(color: AppTokens.hairline)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
