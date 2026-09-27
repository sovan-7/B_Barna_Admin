import 'dart:typed_data';

import 'package:bbarna/core/widgets/form/form_fields.dart';
import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';

/// The teacher's photo: a round preview (the shape it has in the list)
/// with Choose / Replace / Remove buttons.
///
/// Shows the newly picked [bytes] first, then the teacher's current
/// [existingUrl], then a camera placeholder.
class TeacherPhotoField extends StatelessWidget {
  /// Newly picked photo, not yet uploaded.
  final Uint8List? bytes;

  /// File name of [bytes] (null shows "Selected photo").
  final String? fileName;

  /// The photo the teacher already has (edit mode); empty when none.
  final String existingUrl;

  /// Validation message; turns the circle's border red.
  final String? error;

  /// False while saving.
  final bool enabled;

  final VoidCallback onPick;
  final VoidCallback onRemove;

  const TeacherPhotoField({
    required this.bytes,
    required this.fileName,
    required this.existingUrl,
    required this.error,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final String? error = this.error;
    final Uint8List? bytes = this.bytes;
    final bool hasNew = bytes != null;
    final bool hasExisting = existingUrl.trim().isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Round preview; tapping it picks a photo too.
        Material(
          color: AppTokens.surfaceMuted,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: enabled ? onPick : null,
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
                    ? Image.memory(bytes, fit: BoxFit.cover)
                    : hasExisting
                        ? Image.network(existingUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => _placeholder())
                        : _placeholder(),
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
                    ? (fileName ?? "Selected photo")
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
                    onPressed: enabled ? onPick : null,
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
                      onPressed: enabled ? onRemove : null,
                      style: TextButton.styleFrom(
                          foregroundColor: AppTokens.danger,
                          padding: const EdgeInsets.symmetric(horizontal: 10)),
                      child: const Text("Remove",
                          style: TextStyle(fontSize: 12.5)),
                    ),
                  ],
                ],
              ),
              if (error != null) FieldErrorText(error, gap: 6),
            ],
          ),
        ),
      ],
    );
  }

  /// Grey circle with a camera icon.
  Widget _placeholder() => Container(
        color: AppTokens.surfaceMuted,
        alignment: Alignment.center,
        child: const Icon(Icons.add_a_photo_outlined,
            size: 24, color: AppTokens.inkFaint),
      );
}

/// Admin / Subadmin as two radio cards, each saying what it grants.
class TeacherRoleSelector extends StatelessWidget {
  /// The chosen role ([roleAdmin] or [roleSubadmin]).
  final String selectedRole;

  /// False while saving.
  final bool enabled;

  final ValueChanged<String> onSelect;

  const TeacherRoleSelector({
    required this.selectedRole,
    required this.enabled,
    required this.onSelect,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final String role in roleList) ...[
          _option(role),
          if (role != roleList.last) const SizedBox(height: AppTokens.gapSm),
        ],
      ],
    );
  }

  /// One radio card (amber for Admin, blue for Subadmin).
  Widget _option(String role) {
    final bool selected = selectedRole == role;
    final bool isAdmin = role == roleAdmin;
    final Color accent =
        isAdmin ? const Color(0xFFB54708) : const Color(0xFF2563EB);

    return Material(
      color: selected ? accent.withValues(alpha: .07) : AppTokens.surface,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: InkWell(
        key: Key('role_option_$role'),
        onTap: enabled ? () => onSelect(role) : null,
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
}

/// "MODULE ACCESS" section: one tappable chip per module in [moduleList],
/// a live "3 of 13 selected" count, and a Select all / Clear all button.
class ModuleAccessSection extends StatelessWidget {
  /// Stored names of the modules currently ticked.
  final Set<String> selectedModules;

  /// Validation message (e.g. nothing ticked).
  final String? error;

  /// False while saving.
  final bool enabled;

  /// Select all, or clear all when everything is already ticked.
  final VoidCallback onToggleAll;

  /// Ticks / unticks one module (by stored name).
  final ValueChanged<String> onToggle;

  const ModuleAccessSection({
    required this.selectedModules,
    required this.error,
    required this.enabled,
    required this.onToggleAll,
    required this.onToggle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final String? error = this.error;
    final bool allSelected = selectedModules.length == moduleList.length;

    return FormSection(
      title: "MODULE ACCESS",
      trailing: TextButton(
        key: const Key('teacher_toggle_all_modules'),
        onPressed: enabled ? onToggleAll : null,
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
            for (int i = 0; i < moduleList.length; i++) _chip(i),
          ],
        ),
        if (error != null) FieldErrorText(error, gap: AppTokens.gapSm),
      ],
    );
  }

  /// One module chip: its icon and human label; blue with a tick when
  /// selected.
  Widget _chip(int index) {
    final String module = moduleList[index];
    final bool selected = selectedModules.contains(module);
    const Color accent = Color(0xFF2563EB);

    return Material(
      color: selected ? accent.withValues(alpha: .10) : AppTokens.surface,
      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      child: InkWell(
        // Keyed by the stored module name (what a teacher's access list
        // holds).
        key: Key('module_checkbox_$module'),
        onTap: enabled ? () => onToggle(module) : null,
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
}
