import 'package:bbarna/core/widgets/form/form_fields.dart';
import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:bbarna/live_class/widgets/live_class_theme.dart';
import 'package:flutter/material.dart';

/// Label + dropdown + error for the live class form (Subject, Teacher), in
/// [LiveClassTheme] styling. Each option shows [icon] before its text.
class LiveClassDropdownField extends StatelessWidget {
  /// Key on the inner [DropdownButton] (tests open it through this).
  final Key dropdownKey;

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

  /// Validation message; turns the border red.
  final String? error;

  /// Called with the chosen option; null disables the dropdown (e.g. while
  /// its options load).
  final ValueChanged<String?>? onChanged;

  /// Why the options could not be loaded, or null (shown with Retry).
  final String? loadError;

  /// Loads the options again.
  final VoidCallback? onRetry;

  const LiveClassDropdownField({
    required this.dropdownKey,
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.icon,
    required this.error,
    required this.onChanged,
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
        Text(label, style: LiveClassTheme.fieldLabel),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: LiveClassTheme.surface,
            borderRadius: BorderRadius.circular(LiveClassTheme.radiusMd),
            border: Border.all(
                color: error != null
                    ? LiveClassTheme.danger
                    : LiveClassTheme.hairline),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: dropdownKey,
              value: value,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              borderRadius: BorderRadius.circular(LiveClassTheme.radiusMd),
              icon: const Icon(Icons.keyboard_arrow_down,
                  size: 20, color: LiveClassTheme.inkFaint),
              hint: Text(hint,
                  style: const TextStyle(
                      fontSize: 13, color: LiveClassTheme.inkFaint)),
              // DropdownButton takes `style` verbatim; take the font from the
              // theme and pin the decoration off, or WidgetsApp's fallback
              // style paints a yellow double underline under every option.
              style:
                  (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
                      .copyWith(
                fontSize: 13.5,
                color: LiveClassTheme.ink,
                decoration: TextDecoration.none,
              ),
              onChanged: onChanged,
              items: items
                  .map((String item) => DropdownMenuItem<String>(
                        value: item,
                        child: Row(
                          children: [
                            Icon(icon,
                                size: 15, color: LiveClassTheme.inkFaint),
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
        if (error != null) ...[
          const SizedBox(height: 5),
          Text(error, style: LiveClassTheme.errorText),
        ] else if (loadError != null)
          LoadErrorLine(message: loadError, onRetry: onRetry),
      ],
    );
  }
}

/// Label + a tappable box that opens a picker (the class date, start and
/// end times) + error. The box shows [text] in bold once a value [isSet].
class LiveClassPickerField extends StatelessWidget {
  /// Key on the tappable box (tests tap it).
  final Key fieldKey;

  /// Text above the box.
  final String label;

  /// Leading icon (calendar or clock).
  final IconData icon;

  /// The chosen value, formatted, or a prompt.
  final String text;

  /// Whether a value has been chosen.
  final bool isSet;

  /// Validation message; turns the border red.
  final String? error;

  /// Opens the picker.
  final VoidCallback onTap;

  const LiveClassPickerField({
    required this.fieldKey,
    required this.label,
    required this.icon,
    required this.text,
    required this.isSet,
    required this.error,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final String? error = this.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: LiveClassTheme.fieldLabel),
        const SizedBox(height: 6),
        Material(
          color: LiveClassTheme.surface,
          borderRadius: BorderRadius.circular(LiveClassTheme.radiusMd),
          child: InkWell(
            key: fieldKey,
            onTap: onTap,
            borderRadius: BorderRadius.circular(LiveClassTheme.radiusMd),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(LiveClassTheme.radiusMd),
                border: Border.all(
                    color: error != null
                        ? LiveClassTheme.danger
                        : LiveClassTheme.hairline),
              ),
              child: Row(
                children: [
                  Icon(icon,
                      size: 17,
                      color: isSet
                          ? LiveClassTheme.inkMuted
                          : LiveClassTheme.inkFaint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isSet ? FontWeight.w600 : FontWeight.normal,
                        color: isSet
                            ? LiveClassTheme.ink
                            : LiveClassTheme.inkFaint,
                      ),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down,
                      size: 18, color: LiveClassTheme.inkFaint),
                ],
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 5),
          Text(error, style: LiveClassTheme.errorText),
        ],
      ],
    );
  }
}

/// A rounded quick-pick chip ("Tomorrow", "60 min"), tinted when selected.
class LiveClassChoiceChip extends StatelessWidget {
  /// Chip text.
  final String label;

  /// Whether this chip is the current choice.
  final bool selected;

  /// Applies this choice.
  final VoidCallback onTap;

  /// False greys the label and ignores taps.
  final bool enabled;

  const LiveClassChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = LiveClassTheme.accentFor(LiveClassStatus.upcoming);

    return Material(
      color: selected
          ? LiveClassTheme.tintFor(LiveClassStatus.upcoming)
          : LiveClassTheme.surface,
      borderRadius: BorderRadius.circular(LiveClassTheme.radiusPill),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(LiveClassTheme.radiusPill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(LiveClassTheme.radiusPill),
            border:
                Border.all(color: selected ? accent : LiveClassTheme.hairline),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: !enabled
                  ? LiveClassTheme.inkFaint
                  : selected
                      ? accent
                      : LiveClassTheme.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// One-line recap of the schedule under the time fields, e.g.
/// "Tue, 3 Mar · 10:00 – 11:00 · 1 hr", coloured by the status the class
/// would have (upcoming / live / past).
class LiveClassScheduleSummary extends StatelessWidget {
  /// The class as it would be saved (for its status and schedule text).
  final LiveClassModel preview;

  /// Start date-time.
  final DateTime start;

  /// End date-time.
  final DateTime end;

  const LiveClassScheduleSummary({
    required this.preview,
    required this.start,
    required this.end,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final LiveClassStatus status = preview.status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: LiveClassTheme.tintFor(status),
        borderRadius: BorderRadius.circular(LiveClassTheme.radiusMd),
        border: Border.all(color: LiveClassTheme.borderFor(status)),
      ),
      child: Row(
        children: [
          Icon(LiveClassTheme.iconFor(status),
              size: 16, color: LiveClassTheme.accentFor(status)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "${LiveClassFormat.weekday.format(start)}, "
              "${LiveClassFormat.schedule(preview)}  ·  "
              "${LiveClassFormat.duration(start, end)}",
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: LiveClassTheme.accentFor(status)),
            ),
          ),
        ],
      ),
    );
  }
}
