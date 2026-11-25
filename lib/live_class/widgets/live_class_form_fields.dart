import 'package:bbarna/core/widgets/form/form_fields.dart';
import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:bbarna/live_class/repo/live_class_repo.dart';
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

/// How a subject is told apart from the others: its code, or — for a class
/// saved with a name but no code — that name.
String liveClassSubjectId(LiveClassSubject subject) =>
    subject.code.isNotEmpty ? subject.code : "name:${subject.name}";

/// Label + a box listing the ticked subjects as removable chips + error.
/// Tapping the box opens [_SubjectPickerDialog]: a searchable list of
/// [options] with a checkbox each.
///
/// [selected] keeps the order subjects were ticked in; the first is the one
/// older app versions list the class under. A selected subject missing from
/// [options] (renamed or removed since) is still listed, ticked, so opening
/// the picker never drops it.
class LiveClassMultiSelectField extends StatelessWidget {
  /// Key on the tappable box (tests tap it).
  final Key fieldKey;

  /// Text above the box.
  final String label;

  /// Shown in the box while nothing is ticked.
  final String hint;

  /// Every subject that can be ticked.
  final List<LiveClassSubject> options;

  /// The ticked subjects, in tick order.
  final List<LiveClassSubject> selected;

  /// Validation message; turns the border red.
  final String? error;

  /// A muted line under the box (shown when there is no [error]).
  final String? note;

  /// False while the options load or the form saves: the box and the
  /// chips' × do nothing.
  final bool enabled;

  /// Called with the new selection, in tick order.
  final ValueChanged<List<LiveClassSubject>> onChanged;

  /// Why the options could not be loaded, or null (shown with Retry).
  final String? loadError;

  /// Loads the options again.
  final VoidCallback? onRetry;

  const LiveClassMultiSelectField({
    required this.fieldKey,
    required this.label,
    required this.hint,
    required this.options,
    required this.selected,
    required this.error,
    required this.enabled,
    required this.onChanged,
    this.note,
    this.loadError,
    this.onRetry,
    super.key,
  });

  /// [options] with any selected subject they lack put first.
  List<LiveClassSubject> get _allOptions {
    final Set<String> known = options.map(liveClassSubjectId).toSet();
    return [
      ...selected.where((s) => !known.contains(liveClassSubjectId(s))),
      ...options,
    ];
  }

  Future<void> _openPicker(BuildContext context) async {
    final List<LiveClassSubject>? picked =
        await showDialog<List<LiveClassSubject>>(
      context: context,
      builder: (context) => Theme(
        data: LiveClassTheme.pickerTheme(context),
        child: _SubjectPickerDialog(
            options: _allOptions, initial: selected),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final String? error = this.error;
    final String? loadError = this.loadError;
    final String? note = this.note;
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
            onTap: enabled ? () => _openPicker(context) : null,
            borderRadius: BorderRadius.circular(LiveClassTheme.radiusMd),
            child: Container(
              constraints: const BoxConstraints(minHeight: 46),
              padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(LiveClassTheme.radiusMd),
                border: Border.all(
                    color: error != null
                        ? LiveClassTheme.danger
                        : LiveClassTheme.hairline),
              ),
              child: Row(
                children: [
                  const Icon(Icons.library_books_outlined,
                      size: 16, color: LiveClassTheme.inkFaint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: selected.isEmpty
                        ? Text(hint,
                            style: const TextStyle(
                                fontSize: 13, color: LiveClassTheme.inkFaint))
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final LiveClassSubject s in selected)
                                _chip(s),
                            ],
                          ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.keyboard_arrow_down,
                      size: 20, color: LiveClassTheme.inkFaint),
                ],
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 5),
          Text(error, style: LiveClassTheme.errorText),
        ] else if (loadError != null)
          LoadErrorLine(message: loadError, onRetry: onRetry)
        else if (note != null) ...[
          const SizedBox(height: 5),
          Text(note, style: LiveClassTheme.meta),
        ],
      ],
    );
  }

  /// One ticked subject, with an × that unticks it.
  Widget _chip(LiveClassSubject subject) {
    final String id = liveClassSubjectId(subject);
    final String name = subject.name.isNotEmpty ? subject.name : subject.code;
    return Container(
      key: Key('live_class_subject_chip_$id'),
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: LiveClassTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(LiveClassTheme.radiusPill),
        border: Border.all(color: LiveClassTheme.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: LiveClassTheme.ink),
            ),
          ),
          const SizedBox(width: 2),
          Tooltip(
            message: "Remove $name",
            child: InkWell(
              key: Key('live_class_subject_chip_remove_$id'),
              onTap: enabled
                  ? () => onChanged([
                        for (final LiveClassSubject s in selected)
                          if (liveClassSubjectId(s) != id) s,
                      ])
                  : null,
              borderRadius: BorderRadius.circular(LiveClassTheme.radiusPill),
              child: const Padding(
                padding: EdgeInsets.all(3),
                child: Icon(Icons.close,
                    size: 14, color: LiveClassTheme.inkMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The list [LiveClassMultiSelectField] opens: a search box and one
/// checkbox row per subject. Pops the new selection on Done, or null when
/// dismissed (nothing changes).
class _SubjectPickerDialog extends StatefulWidget {
  /// Every subject that can be ticked.
  final List<LiveClassSubject> options;

  /// The selection it opens with, in tick order.
  final List<LiveClassSubject> initial;

  const _SubjectPickerDialog({required this.options, required this.initial});

  @override
  State<_SubjectPickerDialog> createState() => _SubjectPickerDialogState();
}

class _SubjectPickerDialogState extends State<_SubjectPickerDialog> {
  /// The ticked subjects, in tick order: newly ticked ones go to the end.
  late final List<LiveClassSubject> _picked = [...widget.initial];

  /// What the search box holds, lower-cased and trimmed.
  String _query = "";

  bool _isPicked(LiveClassSubject subject) {
    final String id = liveClassSubjectId(subject);
    return _picked.any((s) => liveClassSubjectId(s) == id);
  }

  void _toggle(LiveClassSubject subject) {
    final String id = liveClassSubjectId(subject);
    setState(() {
      if (_isPicked(subject)) {
        _picked.removeWhere((s) => liveClassSubjectId(s) == id);
      } else {
        _picked.add(subject);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<LiveClassSubject> shown = _query.isEmpty
        ? widget.options
        : widget.options
            .where((s) =>
                s.name.toLowerCase().contains(_query) ||
                s.code.toLowerCase().contains(_query))
            .toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text("Select subjects",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: LiveClassTheme.ink)),
                  ),
                  Text("${_picked.length} selected",
                      key: const Key('live_class_subject_count'),
                      style: LiveClassTheme.meta),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: TextField(
                key: const Key('live_class_subject_search'),
                autofocus: true,
                onChanged: (text) =>
                    setState(() => _query = text.toLowerCase().trim()),
                style:
                    const TextStyle(fontSize: 13.5, color: LiveClassTheme.ink),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: "Search by name or code",
                  hintStyle: const TextStyle(
                      fontSize: 13, color: LiveClassTheme.inkFaint),
                  prefixIcon: const Icon(Icons.search,
                      size: 18, color: LiveClassTheme.inkFaint),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(LiveClassTheme.radiusMd),
                    borderSide:
                        const BorderSide(color: LiveClassTheme.hairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(LiveClassTheme.radiusMd),
                    borderSide:
                        const BorderSide(color: LiveClassTheme.hairline),
                  ),
                ),
              ),
            ),
            Flexible(
              child: shown.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        widget.options.isEmpty
                            ? "No Full Course subjects found"
                            : "No subjects match your search",
                        textAlign: TextAlign.center,
                        style: LiveClassTheme.meta,
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: shown.length,
                      itemBuilder: (context, index) {
                        final LiveClassSubject s = shown[index];
                        return CheckboxListTile(
                          key: Key(
                              'live_class_subject_option_${liveClassSubjectId(s)}'),
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          value: _isPicked(s),
                          onChanged: (_) => _toggle(s),
                          title: Text(
                            s.name.isNotEmpty ? s.name : s.code,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: LiveClassTheme.ink),
                          ),
                          subtitle: s.code.isEmpty
                              ? null
                              : Text(s.code, style: LiveClassTheme.meta),
                        );
                      },
                    ),
            ),
            const Divider(height: 1, color: LiveClassTheme.hairline),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  TextButton(
                    key: const Key('live_class_subject_clear'),
                    onPressed: _picked.isEmpty
                        ? null
                        : () => setState(_picked.clear),
                    child: const Text("Clear"),
                  ),
                  const Spacer(),
                  TextButton(
                    key: const Key('live_class_subject_cancel'),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    key: const Key('live_class_subject_done'),
                    onPressed: () => Navigator.pop(context, [..._picked]),
                    child: const Text("Done"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
