import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

/// The row under a list's stats: the search box on the left, filters
/// (chips, a dropdown) on the right. On a narrow window the filters drop
/// under the search box.
class ListToolbar extends StatelessWidget {
  /// Usually a `ListSearchField`.
  final Widget search;

  /// Chips, dropdowns, a sort toggle — whatever narrows the list.
  final List<Widget> filters;

  const ListToolbar({required this.search, this.filters = const [], super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (filters.isEmpty) return search;
      if (constraints.maxWidth < 760) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            search,
            const SizedBox(height: AppTokens.gapSm),
            Wrap(
                spacing: AppTokens.gapSm,
                runSpacing: AppTokens.gapSm,
                children: filters),
          ],
        );
      }
      return Row(
        children: [
          Flexible(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: search)),
          const SizedBox(width: AppTokens.gapMd),
          const Spacer(),
          Wrap(
            spacing: AppTokens.gapSm,
            runSpacing: AppTokens.gapSm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: filters,
          ),
        ],
      );
    });
  }
}

/// A pill-shaped dropdown that narrows a list to one parent ("All courses"
/// ▾ → "WBCS Prelims 2027"). Null is the "all" choice.
class FilterDropdown<T> extends StatelessWidget {
  /// Shown when nothing is picked, e.g. "All courses".
  final String allLabel;

  /// value → label, in the order offered.
  final Map<T, String> options;

  /// The value picked, or null for all.
  final T? selected;

  /// Called with the picked value, or null for all.
  final ValueChanged<T?> onChanged;

  /// Key on the dropdown (tests open it through this).
  final Key? dropdownKey;

  const FilterDropdown({
    required this.allLabel,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.dropdownKey,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bool active = selected != null && options.containsKey(selected);
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        color: active ? AppTokens.accentTint : AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border:
            Border.all(color: active ? AppTokens.accent : AppTokens.hairline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          key: dropdownKey,
          value: active ? selected : null,
          isDense: true,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          icon: const Icon(Icons.keyboard_arrow_down,
              size: 18, color: AppTokens.inkMuted),
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: active ? AppTokens.accentInk : AppTokens.inkMuted),
          onChanged: onChanged,
          items: [
            DropdownMenuItem<T?>(value: null, child: Text(allLabel)),
            for (final MapEntry<T, String> option in options.entries)
              DropdownMenuItem<T?>(
                value: option.key,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(option.value, overflow: TextOverflow.ellipsis),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Whether the window is wide enough for tables at all.
bool isWideList(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= AppTokens.compactBreakpoint;

/// A list body that is a table when there is room for its columns and
/// cards otherwise. Decided on the width the list actually gets (the rail
/// and page padding taken off), not the window's, so a table never
/// squeezes its name column to nothing.
class WideOrNarrow extends StatelessWidget {
  /// Narrowest width the table still reads well at.
  final double minWidth;

  /// The table.
  final WidgetBuilder wide;

  /// The cards.
  final WidgetBuilder narrow;

  const WideOrNarrow({
    required this.minWidth,
    required this.wide,
    required this.narrow,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          isWideList(context) && constraints.maxWidth >= minWidth
              ? wide(context)
              : narrow(context),
    );
  }
}

/// One choice in a [FilterChipBar].
class FilterOption<T> {
  /// The value picked when this chip is tapped (null is a valid value,
  /// usually meaning "All").
  final T value;

  /// Chip text.
  final String label;

  /// Key on the tappable chip (tests tap through it).
  final Key? key;

  const FilterOption(this.value, this.label, {this.key});
}

/// A single-choice row of pill chips ("All · Visible · Hidden · Locked").
/// The selected chip is filled with the accent.
class FilterChipBar<T> extends StatelessWidget {
  /// The chips, left to right.
  final List<FilterOption<T>> options;

  /// The value currently picked.
  final T selected;

  /// Called with the tapped chip's value.
  final ValueChanged<T> onChanged;

  const FilterChipBar({
    required this.options,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final FilterOption<T> option in options) _chip(option)],
    );
  }

  Widget _chip(FilterOption<T> option) {
    final bool isSelected = option.value == selected;
    final BorderRadius radius = BorderRadius.circular(AppTokens.radiusPill);

    return Semantics(
      selected: isSelected,
      button: true,
      child: Material(
        color: isSelected ? AppTokens.accent : AppTokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
              color: isSelected ? AppTokens.accent : AppTokens.hairline),
        ),
        child: InkWell(
          key: option.key,
          onTap: () => onChanged(option.value),
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(option.label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color:
                        isSelected ? AppTokens.onAccent : AppTokens.inkMuted)),
          ),
        ),
      ),
    );
  }
}
