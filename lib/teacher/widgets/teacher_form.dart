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

/// Lets widget tests set a photo without driving the real file picker
/// (which cannot run in tests). [TeacherForm]'s state implements it.
abstract class TeacherFormTestHooks extends State<TeacherForm> {
  /// Sets the photo as if it had been picked (tests only).
  void setSelectedImageForTest(PlatformFile file);
}

/// The Add/Edit Teacher page. One responsive form serves both Add and Edit; the thin screens in
/// `screen/` just choose the mode ([existing] null means Add).
///
/// Sections: account (name, username, password, phone, photo), role and
/// module access. The username cannot change once created.
class TeacherForm extends StatefulWidget {
  /// The item being edited; null means "Add".
  final TeacherModel? existing;
  const TeacherForm({this.existing, super.key});

  /// True when editing an existing item.
  bool get isEdit => existing != null;

  @override
  State<TeacherForm> createState() => _TeacherFormState();
}

/// The fields that can carry an inline error.
enum _Field { name, username, password, phone, photo, modules }

class _TeacherFormState extends TeacherFormTestHooks {
  /// Text of the name field.
  final TextEditingController nameController = TextEditingController();

  /// Text of the username field.
  final TextEditingController usernameController = TextEditingController();

  /// Text of the password field.
  final TextEditingController passwordController = TextEditingController();

  /// Text of the phone number field.
  final TextEditingController phoneController = TextEditingController();

  /// Whether the password field shows its text.
  bool isPasswordVisible = false;

  /// True while saving or deleting; disables every control.
  bool isSaving = false;

  /// The picked photo file (name, size, bytes).
  PlatformFile? selectedImageFile;

  /// Newly picked file, not uploaded yet (null until one is chosen).
  Uint8List? selectedImageBytes;

  /// Stored names of the modules ticked.
  final Set<String> selectedModules = {};

  /// Least-privilege default — Admin must be picked deliberately.
  String selectedRole = roleSubadmin;

  /// Largest photo accepted (5 MB).
  static const int _maxImageBytes = 5 * 1024 * 1024;

  /// Photo file types accepted.
  static const Set<String> _allowedImageExtensions = {'jpg', 'jpeg', 'png'};

  /// Inline error per field: filled on a failed submit, then refreshed on
  /// every change so each message clears as its field is fixed.
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

  /// [file]'s extension in lower case, or null if it has none.
  String? _extensionOf(PlatformFile file) {
    final int dotIndex = file.name.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == file.name.length - 1) return null;
    return file.name.substring(dotIndex + 1).toLowerCase();
  }

  /// Opens the file picker for a photo.
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

  /// Checks every field and returns all the problems at once, each shown on
  /// its own field (empty when valid).
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

  /// Validates, then creates or updates the teacher. Closes the page on
  /// success.
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

  /// The scrolling form (header and sections) with the action bar below.
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

  /// Password box with a show/hide button ("New password" when editing).
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
