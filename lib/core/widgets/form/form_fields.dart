import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/utils/formatters.dart';
import 'package:bbarna/utils/image_sizing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Red message under a field that failed validation.
class FieldErrorText extends StatelessWidget {
  /// The error text.
  final String message;

  /// Gap above the message.
  final double gap;

  const FieldErrorText(this.message, {this.gap = 5, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: gap),
      child: Text(message, style: AppTokens.errorText),
    );
  }
}

/// A labelled, full-width, bordered text input used on every form.
///
/// The border turns red and [error] is shown underneath when validation
/// fails; otherwise an optional grey [note] is shown there. Everything that
/// changes how typing behaves (keyboard, formatters, obscuring) is passed
/// straight to the inner [TextField].
class FormTextField extends StatelessWidget {
  /// Text above the box, e.g. "Course name".
  final String label;

  /// Placeholder inside the empty box.
  final String hint;

  /// Holds the text (owned by the form).
  final TextEditingController controller;

  /// Validation message; turns the border red. Null when valid.
  final String? error;

  /// Grey help text under the box (only when there is no [error]).
  final String? note;

  /// Called on every keystroke (usually to re-validate).
  final VoidCallback? onChanged;

  /// Key on the inner [TextField] (tests type into it).
  final Key? fieldKey;

  /// Lines of text the box shows.
  final int maxLines;

  /// False greys the box and blocks typing.
  final bool enabled;

  /// Hides the text (passwords).
  final bool obscureText;

  /// Keyboard to show; null uses the platform default.
  final TextInputType? keyboardType;

  /// Filters applied while typing (digits only, upper-case, …).
  final List<TextInputFormatter>? inputFormatters;

  /// Icon at the start of the box.
  final IconData? prefixIcon;

  /// Text at the start of the box (e.g. "₹ ").
  final String? prefixText;

  /// Widget at the end of the box (e.g. a show-password button).
  final Widget? suffix;

  /// Style of [label].
  final TextStyle labelStyle;

  const FormTextField({
    required this.label,
    required this.hint,
    required this.controller,
    this.error,
    this.note,
    this.onChanged,
    this.fieldKey,
    this.maxLines = 1,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.prefixIcon,
    this.prefixText,
    this.suffix,
    this.labelStyle = AppTokens.fieldLabel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final String? error = this.error;
    final String? note = this.note;
    final VoidCallback? onChanged = this.onChanged;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
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
            obscureText: obscureText,
            maxLines: maxLines,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: onChanged == null ? null : (_) => onChanged(),
            style: const TextStyle(fontSize: 13.5, color: AppTokens.ink),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle:
                  const TextStyle(fontSize: 13, color: AppTokens.inkFaint),
              prefixIcon: prefixIcon == null
                  ? null
                  : Icon(prefixIcon, size: 17, color: AppTokens.inkFaint),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 38, minHeight: 20),
              prefixText: prefixText,
              prefixStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.inkMuted),
              suffixIcon: suffix,
              contentPadding:
                  EdgeInsets.fromLTRB(prefixIcon == null ? 14 : 0, 13, 14, 13),
            ),
          ),
        ),
        if (error != null)
          FieldErrorText(error)
        else if (note != null) ...[
          const SizedBox(height: 5),
          Text(note,
              style: const TextStyle(
                  fontSize: 11.5, height: 1.35, color: AppTokens.inkFaint)),
        ],
      ],
    );
  }
}

/// A title + explanation on the left and a [Switch] on the right, so the
/// consequence of the toggle is spelled out.
class FormToggleRow extends StatelessWidget {
  /// Bold first line.
  final String title;

  /// What turning it on means for students.
  final String subtitle;

  /// Whether the switch is on.
  final bool value;

  /// Null disables the switch (e.g. while saving).
  final ValueChanged<bool>? onChanged;

  const FormToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.ink)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 11.5, height: 1.35, color: AppTokens.inkFaint)),
            ],
          ),
        ),
        const SizedBox(width: AppTokens.gapMd),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: AppTokens.ink,
        ),
      ],
    );
  }
}

/// Thin grey line between two [FormToggleRow]s.
class FormToggleDivider extends StatelessWidget {
  const FormToggleDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(
        height: AppTokens.gapLg, thickness: 1, color: AppTokens.hairline);
  }
}

/// A square image well with Choose/Replace and Remove buttons.
///
/// Shows, in order of preference: the newly picked [bytes], the item's
/// current [existingUrl], or an "add photo" placeholder. Tapping the well
/// or the button calls [onPick].
class FormImagePickerField extends StatelessWidget {
  /// Newly picked image, not yet uploaded.
  final Uint8List? bytes;

  /// File name of [bytes].
  final String fileName;

  /// The image the item already has (edit mode); empty when none.
  final String existingUrl;

  /// Validation message; turns the well's border red.
  final String? error;

  /// False while saving: nothing can be tapped.
  final bool enabled;

  /// Opens the image picker.
  final VoidCallback onPick;

  /// Clears [bytes] (the "Remove" button, shown only for a new pick).
  final VoidCallback onRemove;

  const FormImagePickerField({
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
        // The square preview / drop target.
        SizedBox(
          height: 108,
          width: 108,
          child: Material(
            color: AppTokens.surfaceMuted,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            child: InkWell(
              onTap: enabled ? onPick : null,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  border: Border.all(
                    color: error != null
                        ? AppTokens.danger
                        : AppTokens.inkFaint.withValues(alpha: .4),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd - 1),
                  child: hasNew
                      ? Image(
                          image: sizedForBox(context, MemoryImage(bytes), 108),
                          fit: BoxFit.cover)
                      : hasExisting
                          ? Image(
                              image: sizedForBox(
                                  context, NetworkImage(existingUrl), 108),
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => _placeholder())
                          : _placeholder(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppTokens.gapMd),
        // File name, size / hint, and the buttons.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasNew
                    ? (fileName.isEmpty ? "Selected image" : fileName)
                    : hasExisting
                        ? "Using the current image"
                        : "No image chosen",
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.ink),
              ),
              const SizedBox(height: 3),
              Text(
                hasNew
                    ? readableFileSize(bytes.lengthInBytes)
                    : "Square images work best — it is shown as a thumbnail.",
                style: const TextStyle(
                    fontSize: 11.5, height: 1.35, color: AppTokens.inkFaint),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton(
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
                        hasNew || hasExisting ? "Replace" : "Choose image",
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

  /// Grey tile with an "add photo" icon.
  Widget _placeholder() => Container(
        color: AppTokens.surfaceMuted,
        alignment: Alignment.center,
        child: const Icon(Icons.add_photo_alternate_outlined,
            size: 26, color: AppTokens.inkFaint),
      );
}

/// "Access": a FREE / PAID choice shown as two segments (with only two
/// options, a dropdown would hide half the answer behind a tap).
class FormAccessTypeField extends StatelessWidget {
  /// The options, e.g. `["FREE", "PAID"]`.
  final List<String> types;

  /// The chosen option, or null.
  final String? selected;

  /// Segment keys are `<keyPrefix>_type_<type lower-case>`.
  final String keyPrefix;

  /// Validation message; turns the border red.
  final String? error;

  /// False while saving.
  final bool enabled;

  /// Called with the chosen option.
  final ValueChanged<String> onSelect;

  const FormAccessTypeField({
    required this.types,
    required this.selected,
    required this.keyPrefix,
    required this.error,
    required this.enabled,
    required this.onSelect,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final String? error = this.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Access", style: AppTokens.fieldLabel),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppTokens.surface,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(
                color: error != null ? AppTokens.danger : AppTokens.hairline),
          ),
          child: Row(
            children: [
              for (final String type in types)
                Expanded(
                  child: _segment(
                    key: Key('${keyPrefix}_type_${type.toLowerCase()}'),
                    label: type == "FREE" ? "Free" : "Paid",
                    icon: type == "FREE"
                        ? Icons.lock_open_outlined
                        : Icons.paid_outlined,
                    selected: selected == type,
                    onTap: () => onSelect(type),
                  ),
                ),
            ],
          ),
        ),
        if (error != null) FieldErrorText(error),
      ],
    );
  }

  /// One option; dark when selected.
  Widget _segment({
    required Key key,
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTokens.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 14, color: selected ? Colors.white : AppTokens.inkFaint),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppTokens.inkMuted)),
          ],
        ),
      ),
    );
  }
}

/// A labelled dropdown styled like [FormTextField]; each option shows
/// [icon] before its text.
class FormDropdownField extends StatelessWidget {
  /// Key on the inner [DropdownButton] (tests open it through this).
  final Key? dropdownKey;

  /// Text above the box.
  final String label;

  /// Shown while nothing is selected.
  final String hint;

  /// The selected option, or null.
  final String? value;

  /// The options.
  final List<String> items;

  /// Icon shown before every option.
  final IconData icon;

  /// Null disables the dropdown.
  final ValueChanged<String?>? onChanged;

  /// Validation message; turns the border red.
  final String? error;

  /// False greys out the box (pass the same condition that nulls
  /// [onChanged] when it should look disabled).
  final bool enabled;

  /// Why the options could not be loaded, or null. Shown under the box with
  /// a Retry link (when [onRetry] is given).
  final String? loadError;

  /// Loads the options again.
  final VoidCallback? onRetry;

  const FormDropdownField({
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
    this.dropdownKey,
    this.error,
    this.enabled = true,
    this.loadError,
    this.onRetry,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final String? error = this.error;
    final String? loadError = this.loadError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTokens.fieldLabel),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: enabled ? AppTokens.surface : AppTokens.surfaceMuted,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(
                color: error != null ? AppTokens.danger : AppTokens.hairline),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: dropdownKey,
              value: value,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              icon: const Icon(Icons.keyboard_arrow_down,
                  size: 20, color: AppTokens.inkFaint),
              hint: Text(hint,
                  style:
                      const TextStyle(fontSize: 13, color: AppTokens.inkFaint)),
              // Built from the theme with the decoration pinned off:
              // DropdownButton uses `style` verbatim instead of merging it,
              // and inheriting DefaultTextStyle above a Scaffold would pick
              // up WidgetsApp's yellow double-underline error style.
              style:
                  (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
                      .copyWith(
                fontSize: 13.5,
                color: AppTokens.ink,
                decoration: TextDecoration.none,
              ),
              onChanged: onChanged,
              items: items
                  .map((String item) => DropdownMenuItem<String>(
                        value: item,
                        child: Row(
                          children: [
                            Icon(icon, size: 15, color: AppTokens.inkFaint),
                            const SizedBox(width: 8),
                            Expanded(
                              child:
                                  Text(item, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
        if (error != null)
          FieldErrorText(error)
        else if (loadError != null)
          LoadErrorLine(message: loadError, onRetry: onRetry),
      ],
    );
  }
}

/// A red "Couldn't load …" line with a Retry link, shown under a field
/// whose options failed to load.
class LoadErrorLine extends StatelessWidget {
  /// e.g. "Couldn't load subjects".
  final String message;

  /// Loads again; no link when null.
  final VoidCallback? onRetry;

  const LoadErrorLine({required this.message, this.onRetry, super.key});

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onRetry = this.onRetry;
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          Flexible(child: Text(message, style: AppTokens.errorText)),
          if (onRetry != null) ...[
            const SizedBox(width: 6),
            InkWell(
              key: const Key('field_retry'),
              onTap: onRetry,
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text("Retry",
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTokens.ink,
                        decoration: TextDecoration.underline)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
