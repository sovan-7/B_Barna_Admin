import 'package:bbarna/core/widgets/form/admin_form_scaffold.dart';
import 'package:bbarna/core/widgets/form/form_action_bar.dart';
import 'package:bbarna/core/widgets/form/form_fields.dart';
import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/teacher/model/teacher_model.dart';
import 'package:bbarna/teacher/viewModel/teacher_view_model.dart';
import 'package:bbarna/teacher/widgets/teacher_form_fields.dart';
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
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username) || username.length < 4) {
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
    return AdminFormScaffold(
      headerTitle: "Teachers",
      sidebarIndex: 11,
      body: (context, width) => _page(width),
    );
  }

  Widget _page(double width) {
    return FormPageBody(
      width: width,
      maxWidth: 760,
      actionBar: _actionBar(width),
      children: [
        _pageHeader(),
        const SizedBox(height: AppTokens.gapLg),
        FormSection(title: "ACCOUNT", children: [
          _avatarField(),
          const SizedBox(height: AppTokens.gapLg),
          FormTwoUp(
              width: width,
              left: _textField(
                fieldKey: const Key('teacher_name_field'),
                label: "Full name",
                hint: "e.g. Anita Desai",
                controller: nameController,
                error: _errors[_Field.name],
              ),
              right: _textField(
                fieldKey: const Key('teacher_username_field'),
                label: "Username",
                hint: "Letters, numbers and underscores",
                controller: usernameController,
                error: _errors[_Field.username],
                // The username is the document id, so it cannot
                // change once the teacher exists.
                enabled: !widget.isEdit,
                note: widget.isEdit ? "A username cannot be changed." : null,
              )),
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
        FormSection(title: "ROLE", children: [_roleField()]),
        const SizedBox(height: AppTokens.gapMd),
        _moduleSection(),
        const SizedBox(height: AppTokens.gapXl),
      ],
    );
  }

  /// Back button, title and subtitle at the top of the page.
  Widget _pageHeader() {
    return FormPageHeader(
      title: widget.isEdit ? "Edit teacher" : "Add a teacher",
      subtitle: widget.isEdit
          ? "Update this teacher's details and what they can reach."
          : "Create a sign-in and choose what this teacher can reach.",
      onBack: isSaving ? null : () => Navigator.pop(context),
    );
  }

  /// A [FormTextField] configured for this form.
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
    return FormTextField(
      fieldKey: fieldKey,
      label: label,
      hint: hint,
      controller: controller,
      error: error,
      note: note,
      enabled: enabled,
      obscureText: obscure,
      suffix: suffix,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: _revalidate,
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
        onPressed: () => setState(() => isPasswordVisible = !isPasswordVisible),
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

  /// Round photo preview with Choose / Replace / Remove.
  Widget _avatarField() {
    return TeacherPhotoField(
      bytes: selectedImageBytes,
      fileName: selectedImageFile?.name,
      existingUrl: widget.existing?.imageUrl ?? "",
      error: _errors[_Field.photo],
      enabled: !isSaving,
      onPick: _onSelectImage,
      onRemove: () => setState(() {
        selectedImageFile = null;
        selectedImageBytes = null;
      }),
    );
  }

  /// Admin / Subadmin radio cards.
  Widget _roleField() {
    return TeacherRoleSelector(
      selectedRole: selectedRole,
      enabled: !isSaving,
      onSelect: (role) => setState(() => selectedRole = role),
    );
  }

  /// Module chips with a live count and Select all / Clear all.
  Widget _moduleSection() {
    return ModuleAccessSection(
      selectedModules: selectedModules,
      error: _errors[_Field.modules],
      enabled: !isSaving,
      onToggleAll: () {
        final bool allSelected = selectedModules.length == moduleList.length;
        setState(() {
          if (allSelected) {
            selectedModules.clear();
          } else {
            selectedModules.addAll(moduleList);
          }
        });
        _revalidate();
      },
      onToggle: (module) {
        setState(() {
          if (!selectedModules.remove(module)) selectedModules.add(module);
        });
        _revalidate();
      },
    );
  }

  /// Delete / Cancel / Save bar pinned to the bottom of the page.
  Widget _actionBar(double width) {
    return FormActionBar(
      width: width,
      isSaving: isSaving,
      saveKey: const Key('teacher_save_button'),
      saveLabel: widget.isEdit ? "Update teacher" : "Save teacher",
      onSave: _onSave,
      saveMinWidth: 150,
      maxWidth: 760,
    );
  }
}
