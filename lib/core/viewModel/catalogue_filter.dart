import 'package:bbarna/core/widgets/list_page/filter_chips.dart';
import 'package:flutter/material.dart';

/// The chips above a catalogue list (courses, subjects, units, topics):
/// everything, or only what students can see, what is hidden, or what is
/// locked.
enum CatalogueFilter {
  all("All"),
  visible("Visible"),
  hidden("Hidden"),
  locked("Locked");

  const CatalogueFilter(this.label);

  /// Chip text.
  final String label;

  /// Whether an item with these flags is shown under this filter.
  bool matches({required bool shown, required bool locked}) => switch (this) {
        CatalogueFilter.all => true,
        CatalogueFilter.visible => shown,
        CatalogueFilter.hidden => !shown,
        CatalogueFilter.locked => locked,
      };

  /// The chips, keyed `<keyPrefix>_filter_<name>` for tests.
  static List<FilterOption<CatalogueFilter>> options(String keyPrefix) => [
        for (final CatalogueFilter filter in CatalogueFilter.values)
          FilterOption(filter, filter.label,
              key: Key('${keyPrefix}_filter_${filter.name}')),
      ];
}
