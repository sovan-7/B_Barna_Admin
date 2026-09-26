import 'dart:math' as math;

import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Opens the "valid till" calendar and resolves to the chosen day (date
/// only), or null if it was dismissed.
///
/// The stock `showDatePicker` arrives in Material's purple with a big
/// headline block and an edit-mode toggle, and reads as a system dialog
/// dropped onto the page. This one uses the page's own tokens and puts the
/// usual durations up front as quick picks, so the common case is one tap
/// rather than paging through months. Used for a subject's coupon expiry
/// and a student's enrolment end date.
///
/// [title] heads the dialog ("Coupon valid till"). [presets] are the quick
/// picks, at most four so they fit one row on a phone. [initial] is the
/// currently saved day; with none, or one already past, the calendar opens
/// on [defaultPreset] (the first preset if not given).
Future<DateTime?> showValidTillPicker(
  BuildContext context, {
  required String title,
  required List<DatePreset> presets,
  DateTime? initial,
  DatePreset? defaultPreset,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => ValidTillPicker(
      title: title,
      presets: presets,
      initial: initial,
      defaultPreset: defaultPreset,
    ),
  );
}

/// A quick pick: a label plus how far from today it lands.
class DatePreset {
  final String label;
  final int days;
  final int months;

  const DatePreset.days(this.days, this.label) : months = 0;
  const DatePreset.months(this.months, this.label) : days = 0;

  DateTime from(DateTime today) {
    if (months == 0) return today.add(Duration(days: days));
    // Clamp to the target month's length so 31 Jan + 1 month is 28/29 Feb,
    // not 3 Mar.
    final DateTime month = DateTime(today.year, today.month + months);
    return DateTime(month.year, month.month,
        math.min(today.day, DateUtils.getDaysInMonth(month.year, month.month)));
  }
}

class ValidTillPicker extends StatefulWidget {
  final String title;
  final List<DatePreset> presets;
  final DateTime? initial;
  final DatePreset? defaultPreset;

  const ValidTillPicker({
    required this.title,
    required this.presets,
    this.initial,
    this.defaultPreset,
    super.key,
  }) : assert(presets.length > 0 && presets.length <= 4);

  @override
  State<ValidTillPicker> createState() => _ValidTillPickerState();
}

class _ValidTillPickerState extends State<ValidTillPicker> {
  static final DateFormat _headline = DateFormat("EEE, d MMM yyyy");

  late final DateTime _today;
  late final DateTime _lastDate;
  late DateTime _selected;

  /// [CalendarDatePicker] ignores a new `initialDate` after it is built,
  /// so a quick pick rebuilds it under a fresh key to jump to that month.
  int _calendarVersion = 0;

  List<DatePreset> get _presets => widget.presets;

  @override
  void initState() {
    super.initState();
    _today = DateUtils.dateOnly(DateTime.now());
    _lastDate = DateTime(_today.year + 5, 12, 31);
    final DateTime? initial = widget.initial;
    _selected = initial == null || initial.isBefore(_today)
        ? (widget.defaultPreset ?? _presets.first).from(_today)
        : DateUtils.dateOnly(initial);
  }

  /// Whole days from today, counted on UTC dates so a daylight-saving
  /// change in between doesn't turn 7 days into 6.
  int get _daysLeft => DateTime.utc(
          _selected.year, _selected.month, _selected.day)
      .difference(DateTime.utc(_today.year, _today.month, _today.day))
      .inDays;

  String get _relative {
    final int days = _daysLeft;
    if (days == 0) return "Expires tonight";
    if (days == 1) return "Expires tomorrow";
    if (days < 60) return "Expires in $days days";
    // "730 days" alone is hard to picture for an enrolment, so longer spans
    // also get a rounded figure.
    final int months = (days / 30.44).round();
    final String rough = months % 12 == 0
        ? "${months ~/ 12} year${months == 12 ? '' : 's'}"
        : "$months months";
    return "Expires in $days days · about $rough";
  }

  void _applyPreset(DatePreset preset) {
    setState(() {
      _selected = preset.from(_today);
      _calendarVersion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTokens.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: _quickPicks(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _calendar(context),
              ),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: const BoxDecoration(
        color: AppTokens.surfaceMuted,
        border: Border(bottom: BorderSide(color: AppTokens.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title.toUpperCase(), style: AppTokens.sectionTitle),
          const SizedBox(height: 6),
          Text(
            _headline.format(_selected),
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: AppTokens.ink),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppTokens.surface,
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              border: Border.all(color: AppTokens.hairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule, size: 13, color: AppTokens.inkMuted),
                const SizedBox(width: 5),
                // Flexible so the longer "· about 2 years" form wraps on a
                // narrow phone instead of overflowing the pill.
                Flexible(
                  child: Text(
                    _relative,
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTokens.inkMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One row of equal-width pills, so they line up with the calendar grid
  /// below instead of wrapping ragged.
  Widget _quickPicks() {
    return Row(
      children: [
        for (int i = 0; i < _presets.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _pill(
              label: _presets[i].label,
              selected:
                  DateUtils.isSameDay(_presets[i].from(_today), _selected),
              onTap: () => _applyPreset(_presets[i]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _pill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? AppTokens.ink : AppTokens.surface,
      shape: StadiumBorder(
        side: BorderSide(
            color: selected ? AppTokens.ink : AppTokens.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppTokens.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _calendar(BuildContext context) {
    final ThemeData base = Theme.of(context);
    bool isSelected(Set<WidgetState> s) => s.contains(WidgetState.selected);

    final ThemeData theme = base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: AppTokens.ink,
        onPrimary: Colors.white,
        surface: AppTokens.surface,
        onSurface: AppTokens.ink,
        onSurfaceVariant: AppTokens.inkMuted,
        surfaceTint: Colors.transparent,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppTokens.surface,
        surfaceTintColor: Colors.transparent,
        subHeaderForegroundColor: AppTokens.ink,
        toggleButtonTextStyle: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700, color: AppTokens.ink),
        weekdayStyle: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppTokens.inkFaint),
        dayStyle:
            const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
        dayShape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10))),
        dayForegroundColor: WidgetStateProperty.resolveWith((s) {
          if (isSelected(s)) return Colors.white;
          if (s.contains(WidgetState.disabled)) {
            return AppTokens.inkFaint.withValues(alpha: .55);
          }
          return AppTokens.ink;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
            (s) => isSelected(s) ? AppTokens.ink : Colors.transparent),
        dayOverlayColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.pressed)) {
            return AppTokens.ink.withValues(alpha: .12);
          }
          if (s.contains(WidgetState.hovered) ||
              s.contains(WidgetState.focused)) {
            return AppTokens.ink.withValues(alpha: .06);
          }
          return null;
        }),
        todayForegroundColor: WidgetStateProperty.resolveWith(
            (s) => isSelected(s) ? Colors.white : AppTokens.ink),
        todayBackgroundColor: WidgetStateProperty.resolveWith(
            (s) => isSelected(s) ? AppTokens.ink : Colors.transparent),
        todayBorder: const BorderSide(color: AppTokens.inkFaint),
        yearStyle:
            const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
        yearForegroundColor: WidgetStateProperty.resolveWith((s) {
          if (isSelected(s)) return Colors.white;
          if (s.contains(WidgetState.disabled)) {
            return AppTokens.inkFaint.withValues(alpha: .55);
          }
          return AppTokens.ink;
        }),
        yearBackgroundColor: WidgetStateProperty.resolveWith(
            (s) => isSelected(s) ? AppTokens.ink : Colors.transparent),
        yearShape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10))),
      ),
    );

    return Theme(
      data: theme,
      child: CalendarDatePicker(
        key: ValueKey<int>(_calendarVersion),
        initialDate: _selected,
        currentDate: _today,
        firstDate: _today,
        lastDate: _lastDate,
        onDateChanged: (DateTime date) =>
            setState(() => _selected = DateUtils.dateOnly(date)),
      ),
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTokens.hairline)),
      ),
      child: Row(
        children: [
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppTokens.inkMuted,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text("Cancel"),
          ),
          const SizedBox(width: AppTokens.gapSm),
          ElevatedButton(
            key: const Key('valid_till_confirm'),
            onPressed: () => Navigator.pop(context, _selected),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.ink,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
            ),
            child: const Text("Set date",
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
