import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

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
                    color: isSelected ? Colors.white : AppTokens.inkMuted)),
          ),
        ),
      ),
    );
  }
}
