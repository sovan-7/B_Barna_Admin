import 'package:bbarna/core/widgets/app_header.dart';
import 'package:bbarna/core/widgets/sidebar.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/teacher/model/teacher_model.dart';
import 'package:bbarna/teacher/viewModel/teacher_view_model.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// The seam widget tests reach through to set a photo without driving a
/// real file picker, which is untestable in this environment. It was
/// declared twice, once per screen; there is one form now, so one hook.
abstract class TeacherFormTestHooks extends State<TeacherForm> {
  void setSelectedImageForTest(PlatformFile file);
}

/// The whole Add/Edit Teacher page. [existing] null means Add.
///
/// Add and Edit were two 518 and 520 line screens holding the same form
/// twice over — and four widgets had already been extracted to fix that
/// (`teacher_form_scaffold`, `teacher_avatar_picker`,
/// `teacher_role_selector`, `teacher_module_access_selector`, 406 lines
/// between them) but never wired up, so both screens still carried their
/// own inline copies. The extracted files were dead; this is the one form.
class TeacherForm extends StatefulWidget {
  final TeacherModel? existing;
  const TeacherForm({this.existing, super.key});

  bool get isEdit => existing != null;

  @override
  State<TeacherForm> createState() => _TeacherFormState();
}

/// The fields that can carry an inline error.
enum _Field { name, username, password, phone, photo, modules }

class _TeacherFormState extends TeacherFormTestHooks {
  final GlobalKey<ScaffoldState> key = GlobalKey();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  bool isPasswordVisible = false;
  bool isSaving = false;

  PlatformFile? selectedImageFile;
  Uint8List? selectedImageBytes;

  final Set<String> selectedModules = {};

  /// Least-privilege default — Admin must be picked deliberately.
  String selectedRole = roleSubadmin;

  static const int _maxImageBytes = 5 * 1024 * 1024;
  static const Set<String> _allowedImageExtensions = {'jpg', 'jpeg', 'png'};

  final Map<_Field, String> _errors = {};

  @override
  void initState() {
    super.initState();
    final TeacherModel? existing = widget.existing;
    if (existing != null) {
      nameController.text = existing.name;
      usernameController.text = existing.username;
      phoneController.text = existing.phoneNumber;
      selectedRole = existing.role.isEmpty ? roleSubadmin : existing.role;
      selectedModules.addAll(existing.moduleAccess);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  @visibleForTesting
  void setSelectedImageForTest(PlatformFile file) {
    setState(() {
      selectedImageFile = file;
      selectedImageBytes = file.bytes;
    });
  }

  String? _extensionOf(PlatformFile file) {
    final int dotIndex = file.name.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == file.name.length - 1) return null;
    return file.name.substring(dotIndex + 1).toLowerCase();
  }

  Future<void> _onSelectImage() async {
    final FilePickerResult? picked =
        await FilePicker.platform.pickFiles(type: FileType.image);
    if (picked == null || !mounted) return;
    setState(() {
      selectedImageFile = picked.files.first;
      selectedImageBytes = picked.files.first.bytes;
    });
    _revalidate();
  }

  // ---- Validation -----------------------------------------------------

  /// The rules are unchanged; what is new is that every failure is reported
  /// at once, on the field it belongs to. They used to be a chain of early
  /// returns, one snackbar at a time, with nothing marked on the form.
  Map<_Field, String> _validate() {
    final Map<_Field, String> errors = {};

    final String name = nameController.text.trim();
    if (name.isEmpty || name.length > 100) {
      errors[_Field.name] = "Please enter a name (up to 100 characters)";
    }

    // Letters, numbers, and underscores — a realistic reading of
    // "alphanumeric username" (real handles commonly use underscores);
    // still rejects spaces/punctuation/emoji.
    final String username = usernameController.text.trim();
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username) ||
        username.length < 4) {
      errors[_Field.username] =
          "Username must be at least 4 letters, numbers, or underscores";
    }

    // Hard requirement is length only — letters+numbers is a
    // recommendation, surfaced as guidance under the field.
    final String password = passwordController.text;
    if (widget.isEdit) {
      // Blank means "keep the current password", so only a typed one is
      // checked.
      if (password.isNotEmpty && password.length < 8) {
        errors[_Field.password] = "Password must be at least 8 characters";
      }
    } else if (password.length < 8) {
      errors[_Field.password] = "Password must be at least 8 characters";
    }

    final String phone = phoneController.text.trim();
    if (!RegExp(r'^[0-9]{10}$').hasMatch(phone)) {
      errors[_Field.phone] = "Enter a valid 10-digit phone number";
    }

    final PlatformFile? imageFile = selectedImageFile;
    final Uint8List? imageBytes = selectedImageBytes;
    if (imageFile == null || imageBytes == null) {
      // An edit keeps the photo it already has.
      if (!widget.isEdit) errors[_Field.photo] = "Please choose a photo";
    } else {
      final String? extension = _extensionOf(imageFile);
      if (extension == null || !_allowedImageExtensions.contains(extension)) {
        errors[_Field.photo] = "Photo must be a JPG or PNG file";
      } else if (imageFile.size > _maxImageBytes) {
        errors[_Field.photo] = "Photo must be 5MB or smaller";
      }
    }

    if (selectedModules.isEmpty) {
      errors[_Field.modules] = "Please select at least one module";
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

  Future<void> _onSave() async {
    final Map<_Field, String> errors = _validate();
    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
      });
      Helper.showSnackBarMessage(msg: errors.values.first, isSuccess: false);
      return;
    }

    // Preserve moduleList's order rather than Set iteration order, which is
    // insertion-order-dependent and would make the saved list order flaky.
    final List<String> moduleAccess =
        moduleList.where(selectedModules.contains).toList();

    setState(() {
      _errors.clear();
      isSaving = true;
    });

    final TeacherViewModel teacherViewModel =
        Provider.of<TeacherViewModel>(context, listen: false);

    final bool success = widget.isEdit
        ? await teacherViewModel.updateTeacher(
            original: widget.existing!,
            name: nameController.text.trim(),
            newPassword: passwordController.text,
            phoneNumber: phoneController.text.trim(),
            moduleAccess: moduleAccess,
            role: selectedRole,
            newImage: selectedImageBytes,
          )
        : await teacherViewModel.addTeacher(
            name: nameController.text.trim(),
            username: usernameController.text.trim(),
            password: passwordController.text,
            phoneNumber: phoneController.text.trim(),
            image: selectedImageBytes!,
            moduleAccess: moduleAccess,
            role: selectedRole,
          );

    if (!mounted) return;
    setState(() => isSaving = false);

    if (success) {
      Helper.showSnackBarMessage(
          msg: widget.isEdit
              ? "Teacher updated successfully"
              : "Teacher added successfully",
          isSuccess: true);
      Navigator.pop(context);
    }
  }

  // ---- Layout ---------------------------------------------------------

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
        child: Column(
          children: [
            AppHeader(
              onTapIcon: () => key.currentState?.openDrawer(),
              title: "Teachers",
            ),
            Expanded(
              child: Row(
                children: [
                  if (!isCompact)
                    const Expanded(child: ExtraSideBar(sidebarIndex: 11)),
                  Expanded(flex: 5, child: _page(width)),
                ],
              ),
            ),
          ],
        ),
      ),
      drawer: isCompact
          ? const Drawer(child: ExtraSideBar(sidebarIndex: 11))
          : null,
    );
  }

  Widget _page(double width) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
                horizontal: width < 700 ? 16 : 32, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _pageHeader(),
                    const SizedBox(height: AppTokens.gapLg),
                    _section(title: "ACCOUNT", children: [
                      _avatarField(),
                      const SizedBox(height: AppTokens.gapLg),
                      _twoUp(
                        width,
                        _textField(
                          fieldKey: const Key('teacher_name_field'),
                          label: "Full name",
                          hint: "e.g. Anita Desai",
                          controller: nameController,
                          error: _errors[_Field.name],
                        ),
                        _textField(
                          fieldKey: const Key('teacher_username_field'),
                          label: "Username",
                          hint: "Letters, numbers and underscores",
                          controller: usernameController,
                          error: _errors[_Field.username],
                          // The username is the document id, so it cannot
                          // change once the teacher exists.
                          enabled: !widget.isEdit,
                          note: widget.isEdit
                              ? "A username cannot be changed."
                              : null,
                        ),
                      ),
                      const SizedBox(height: AppTokens.gapMd),
                      _textField(
                        fieldKey: const Key('teacher_phone_field'),
                        label: "Phone number",
                        hint: "10-digit mobile number",
                        controller: phoneController,
                        error: _errors[_Field.phone],
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                      ),
                      const SizedBox(height: AppTokens.gapMd),
                      _passwordField(),
                    ]),
                    const SizedBox(height: AppTokens.gapMd),
                    _section(title: "ROLE", children: [_roleField()]),
                    const SizedBox(height: AppTokens.gapMd),
                    _moduleSection(),
                    const SizedBox(height: AppTokens.gapXl),
                  ],
                ),
              ),
            ),
          ),
        ),
        _actionBar(width),
      ],
    );
  }

  Widget _twoUp(double width, Widget left, Widget right) {
    if (width < 700) {
      return Column(children: [
        left,
        const SizedBox(height: AppTokens.gapMd),
        right,
      ]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: AppTokens.gapMd),
        Expanded(child: right),
      ],
    );
  }

  Widget _pageHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _backButton(),
        const SizedBox(width: AppTokens.gapMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.isEdit ? "Edit teacher" : "Add a teacher",
                  style: AppTokens.pageTitle),
              const SizedBox(height: 3),
              Text(
                widget.isEdit
                    ? "Update this teacher's details and what they can reach."
                    : "Create a sign-in and choose what this teacher can reach.",
                style: AppTokens.pageSubtitle,
              ),
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
        onTap: isSaving ? null : () => Navigator.pop(context),
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

  Widget _section({
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
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
          Row(
            children: [
              Text(title, style: AppTokens.sectionTitle),
              if (trailing != null) ...[const Spacer(), trailing],
            ],
          ),
          const SizedBox(height: AppTokens.gapMd),
          ...children,
        ],
      ),
    );
  }

  static const TextStyle _labelStyle = TextStyle(
      fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF344054));

  Widget _textField({
    required Key fieldKey,
    required String label,
    required String hint,
    required TextEditingController controller,
    String? error,
    String? note,
    bool enabled = true,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: enabled ? AppTokens.surface : AppTokens.surfaceMuted,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(
                color: error != null ? AppTokens.danger : AppTokens.hairline),
          ),
          child: TextField(
            key: fieldKey,
            controller: controller,
            enabled: enabled,
            obscureText: obscure,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: (_) => _revalidate(),
            style: const TextStyle(fontSize: 13.5, color: AppTokens.ink),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle:
                  const TextStyle(fontSize: 13, color: AppTokens.inkFaint),
              suffixIcon: suffix,
              contentPadding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 5),
          Text(error, style: AppTokens.errorText),
        ] else if (note != null) ...[
          const SizedBox(height: 5),
          Text(note,
              style: const TextStyle(
                  fontSize: 11.5, height: 1.35, color: AppTokens.inkFaint)),
        ],
      ],
    );
  }

  Widget _passwordField() {
    return _textField(
      fieldKey: const Key('teacher_password_field'),
      label: widget.isEdit ? "New password" : "Password",
      hint: widget.isEdit
          ? "Leave blank to keep the current one"
          : "At least 8 characters",
      controller: passwordController,
      error: _errors[_Field.password],
      obscure: !isPasswordVisible,
      note: "At least 8 characters. Letters and numbers are recommended.",
      suffix: IconButton(
        onPressed: () =>
            setState(() => isPasswordVisible = !isPasswordVisible),
        tooltip: isPasswordVisible ? "Hide password" : "Show password",
        icon: Icon(
            isPasswordVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 18,
            color: AppTokens.inkFaint),
      ),
    );
  }

  /// The photo, previewed round the way it appears in the list.
  Widget _avatarField() {
    final String? error = _errors[_Field.photo];
    final bool hasNew = selectedImageBytes != null;
    final String existingUrl = widget.existing?.imageUrl ?? "";
    final bool hasExisting = existingUrl.trim().isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: AppTokens.surfaceMuted,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: isSaving ? null : _onSelectImage,
            customBorder: const CircleBorder(),
            child: Container(
              height: 88,
              width: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: error != null
                        ? AppTokens.danger
                        : AppTokens.inkFaint.withValues(alpha: .4)),
              ),
              child: ClipOval(
                child: hasNew
                    ? Image.memory(selectedImageBytes!, fit: BoxFit.cover)
                    : hasExisting
                        ? Image.network(existingUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => _avatarPlaceholder())
                        : _avatarPlaceholder(),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppTokens.gapMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasNew
                    ? (selectedImageFile?.name ?? "Selected photo")
                    : hasExisting
                        ? "Using the current photo"
                        : "No photo chosen",
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.ink),
              ),
              const SizedBox(height: 3),
              const Text("JPG or PNG, up to 5MB.",
                  style: TextStyle(
                      fontSize: 11.5, height: 1.35, color: AppTokens.inkFaint)),
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton(
                    key: const Key('teacher_choose_photo'),
                    onPressed: isSaving ? null : _onSelectImage,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTokens.ink,
                      side: const BorderSide(color: AppTokens.hairline),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTokens.radiusSm)),
                    ),
                    child: Text(
                        hasNew || hasExisting ? "Replace" : "Choose photo",
                        style: const TextStyle(fontSize: 12.5)),
                  ),
                  if (hasNew) ...[
                    const SizedBox(width: AppTokens.gapSm),
                    TextButton(
                      onPressed: isSaving
                          ? null
                          : () => setState(() {
                                selectedImageFile = null;
                                selectedImageBytes = null;
                              }),
                      style: TextButton.styleFrom(
                          foregroundColor: AppTokens.danger,
                          padding: const EdgeInsets.symmetric(horizontal: 10)),
                      child: const Text("Remove",
                          style: TextStyle(fontSize: 12.5)),
                    ),
                  ],
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: 6),
                Text(error, style: AppTokens.errorText),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatarPlaceholder() => Container(
        color: AppTokens.surfaceMuted,
        alignment: Alignment.center,
        child: const Icon(Icons.add_a_photo_outlined,
            size: 24, color: AppTokens.inkFaint),
      );

  /// Each role says what it grants, so the choice is not a guess.
  Widget _roleField() {
    return Column(
      children: [
        for (final String role in roleList) ...[
          _roleOption(role),
          if (role != roleList.last) const SizedBox(height: AppTokens.gapSm),
        ],
      ],
    );
  }

  Widget _roleOption(String role) {
    final bool selected = selectedRole == role;
    final bool isAdmin = role == roleAdmin;
    final Color accent = isAdmin
        ? const Color(0xFFB54708)
        : const Color(0xFF2563EB);

    return Material(
      color: selected ? accent.withValues(alpha: .07) : AppTokens.surface,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: InkWell(
        key: Key('role_option_$role'),
        onTap: isSaving ? null : () => setState(() => selectedRole = role),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(
                color: selected
                    ? accent.withValues(alpha: .55)
                    : AppTokens.hairline,
                width: selected ? 1.4 : 1),
          ),
          child: Row(
            children: [
              Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: selected ? accent : AppTokens.inkFaint),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isAdmin ? "Admin" : "Subadmin",
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: selected ? accent : AppTokens.ink)),
                    const SizedBox(height: 2),
                    Text(
                      isAdmin
                          ? "Full access, including managing other teachers."
                          : "Only the modules ticked below.",
                      style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: AppTokens.inkFaint),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Module access, with a select-all and a live count.
  ///
  /// Ticking thirteen boxes one at a time was the only way to give someone
  /// full access before.
  Widget _moduleSection() {
    final String? error = _errors[_Field.modules];
    final bool allSelected = selectedModules.length == moduleList.length;

    return _section(
      title: "MODULE ACCESS",
      trailing: TextButton(
        key: const Key('teacher_toggle_all_modules'),
        onPressed: isSaving
            ? null
            : () {
                setState(() {
                  if (allSelected) {
                    selectedModules.clear();
                  } else {
                    selectedModules.addAll(moduleList);
                  }
                });
                _revalidate();
              },
        style: TextButton.styleFrom(
            foregroundColor: AppTokens.inkMuted,
            padding: const EdgeInsets.symmetric(horizontal: 8)),
        child: Text(allSelected ? "Clear all" : "Select all",
            style: const TextStyle(fontSize: 12.5)),
      ),
      children: [
        Text(
          "${selectedModules.length} of ${moduleList.length} selected",
          style: const TextStyle(fontSize: 11.5, color: AppTokens.inkFaint),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: AppTokens.gapSm,
          runSpacing: AppTokens.gapSm,
          children: [
            for (int i = 0; i < moduleList.length; i++)
              _moduleChip(i),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: AppTokens.gapSm),
          Text(error, style: AppTokens.errorText),
        ],
      ],
    );
  }

  Widget _moduleChip(int index) {
    final String module = moduleList[index];
    final bool selected = selectedModules.contains(module);
    const Color accent = Color(0xFF2563EB);

    return Material(
      color: selected ? accent.withValues(alpha: .10) : AppTokens.surface,
      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      child: InkWell(
        // Keyed by the stored module name, which is what a teacher's
        // access list holds.
        key: Key('module_checkbox_$module'),
        onTap: isSaving
            ? null
            : () {
                setState(() {
                  if (selected) {
                    selectedModules.remove(module);
                  } else {
                    selectedModules.add(module);
                  }
                });
                _revalidate();
              },
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            border: Border.all(
                color: selected
                    ? accent.withValues(alpha: .5)
                    : AppTokens.hairline,
                width: selected ? 1.3 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? Icons.check_circle : moduleIconList[index],
                  size: 14, color: selected ? accent : AppTokens.inkFaint),
              const SizedBox(width: 7),
              Text(
                // The human label, not the stored SHOUTY constant.
                moduleDisplayList[index],
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? accent : AppTokens.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBar(double width) {
    final bool narrow = width < 560;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: width < 700 ? 16 : 32, vertical: 14),
      decoration: const BoxDecoration(
        color: AppTokens.surface,
        border: Border(top: BorderSide(color: AppTokens.hairline)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Row(
            children: [
              if (!narrow) const Spacer(),
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppTokens.inkMuted,
                  padding: EdgeInsets.symmetric(
                      horizontal: narrow ? 12 : 18, vertical: 14),
                ),
                child: const Text("Cancel"),
              ),
              const SizedBox(width: AppTokens.gapSm),
              _saveButton(expand: narrow),
            ],
          ),
        ),
      ),
    );
  }

  Widget _saveButton({required bool expand}) {
    final Widget button = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150, minHeight: 42),
      child: ElevatedButton(
        key: const Key('teacher_save_button'),
        onPressed: isSaving ? null : _onSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.ink,
          disabledBackgroundColor: AppTokens.ink.withValues(alpha: .55),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
        ),
        child: isSaving
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: Colors.white),
              )
            : Text(widget.isEdit ? "Update teacher" : "Save teacher",
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600)),
      ),
    );

    return expand ? Expanded(child: button) : button;
  }
}
