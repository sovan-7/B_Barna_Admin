import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

/// The card each Topic1 content editor (PDFs, videos) sits in, styled like
/// the Topics module's code lists: icon, title and count on top, the rows,
/// then "Add …" and a Save button that is disabled until something changed.
class Topic1SectionCard extends StatelessWidget {
  /// Icon beside the title.
  final IconData icon;

  /// Section title, e.g. "PDFs".
  final String title;

  /// Shown in the pill beside the title.
  final int count;

  /// One widget per item; [emptyText] is shown when there are none.
  final List<Widget> rows;

  /// Shown when [rows] is empty.
  final String emptyText;

  /// Text of the add button, e.g. "Add a PDF".
  final String addLabel;

  /// Key of the add button.
  final Key addKey;

  /// Adds a row; null disables the button.
  final VoidCallback? onAdd;

  /// Key of the save button.
  final Key saveKey;

  /// True while saving: the save button shows a spinner.
  final bool isSaving;

  /// True when the rows differ from what is saved.
  final bool dirty;

  /// Saves the rows.
  final VoidCallback onSave;

  const Topic1SectionCard({
    required this.icon,
    required this.title,
    required this.count,
    required this.rows,
    required this.emptyText,
    required this.addLabel,
    required this.addKey,
    required this.onAdd,
    required this.saveKey,
    required this.isSaving,
    required this.dirty,
    required this.onSave,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bool isNarrow = MediaQuery.sizeOf(context).width < 560;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppTokens.gapMd),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppTokens.hairline),
        boxShadow: AppTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
              child: Text(emptyText,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppTokens.inkFaint)),
            )
          else
            for (int i = 0; i < rows.length; i++) ...[
              if (i > 0)
                const Divider(
                    height: 1, thickness: 1, color: AppTokens.hairline),
              rows[i],
            ],
          _footer(isNarrow),
        ],
      ),
    );
  }

  /// Icon, title and how many items there are.
  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTokens.hairline)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppTokens.inkMuted),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.ink),
            ),
          ),
          const SizedBox(width: AppTokens.gapSm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTokens.surfaceMuted,
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              border: Border.all(color: AppTokens.hairline),
            ),
            child: Text("$count",
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.inkMuted)),
          ),
        ],
      ),
    );
  }

  /// Add and Save buttons.
  Widget _footer(bool isNarrow) {
    final Widget add = TextButton.icon(
      key: addKey,
      onPressed: onAdd,
      icon: const Icon(Icons.add, size: 16),
      label: Text(addLabel,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5)),
      style: TextButton.styleFrom(
        foregroundColor: AppTokens.inkMuted,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
    );

    final Widget save = ElevatedButton(
      key: saveKey,
      // Disabled until something changed, so the button says whether there
      // is anything to save.
      onPressed: (isSaving || !dirty) ? null : onSave,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTokens.accent,
        disabledBackgroundColor: AppTokens.surfaceMuted,
        foregroundColor: AppTokens.onAccent,
        disabledForegroundColor: AppTokens.inkFaint,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
      ),
      child: isSaving
          ? const SizedBox(
              height: 15,
              width: 15,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTokens.inkMuted),
            )
          : Text(dirty ? "Save changes" : "Saved",
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 18, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTokens.hairline)),
      ),
      child: isNarrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerLeft, child: add),
                const SizedBox(height: AppTokens.gapSm),
                save,
              ],
            )
          : Row(
              children: [
                Flexible(child: add),
                const Spacer(),
                save,
              ],
            ),
    );
  }
}

/// How an access type reads in a row's summary.
String topic1AccessLabel(String? type) => switch (type) {
      "FREE" => "Free",
      "PAID" => "Paid",
      _ => "No access type",
    };

/// How long a row takes to fold or unfold.
const Duration topic1FoldDuration = Duration(milliseconds: 180);

/// What starts every row: the "1", "2", … badge, the item's title with a
/// one-line summary under it, a button that folds the row's fields away or
/// shows them again, and the remove button. Tapping the title folds and
/// unfolds too, so a long list can be scanned without opening every row.
class Topic1RowHeader extends StatelessWidget {
  /// Position of the row, from 0.
  final int index;

  /// The item's title as typed so far.
  final String title;

  /// Shown in place of [title] while it is empty, e.g. "Untitled PDF".
  final String untitledText;

  /// One line about the item, e.g. "Paid · notes.pdf · Downloadable".
  final String summary;

  /// Whether the row's fields are showing.
  final bool expanded;

  /// Whether the row has an inline error. While the row is folded the
  /// summary turns red, so a folded row never hides a problem.
  final bool hasError;

  /// Key of the fold / unfold button.
  final Key toggleKey;

  /// Folds or unfolds the row.
  final VoidCallback onToggle;

  /// Key of the remove button.
  final Key removeKey;

  /// Removes the row; null disables the button.
  final VoidCallback? onRemove;

  /// Tooltip of the remove button.
  final String removeTooltip;

  const Topic1RowHeader({
    required this.index,
    required this.title,
    required this.untitledText,
    required this.summary,
    required this.expanded,
    required this.hasError,
    required this.toggleKey,
    required this.onToggle,
    required this.removeKey,
    required this.onRemove,
    required this.removeTooltip,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final String shownTitle = title.trim();
    final bool showError = hasError && !expanded;

    return Row(
      children: [
        Container(
          height: 22,
          constraints: const BoxConstraints(minWidth: 22),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTokens.surfaceMuted,
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            border: Border.all(color: AppTokens.hairline),
          ),
          child: Text("${index + 1}",
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTokens.inkMuted)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    shownTitle.isEmpty ? untitledText : shownTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: shownTitle.isEmpty
                            ? AppTokens.inkFaint
                            : AppTokens.ink),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (showError) ...[
                        const Icon(Icons.error_outline,
                            size: 13, color: AppTokens.danger),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          showError ? "Needs fixing · $summary" : summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5,
                              color: showError
                                  ? AppTokens.danger
                                  : AppTokens.inkFaint),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          key: toggleKey,
          tooltip: expanded ? "Hide details" : "Show details",
          onPressed: onToggle,
          icon:
              Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 20),
          color: AppTokens.inkMuted,
        ),
        IconButton(
          key: removeKey,
          tooltip: removeTooltip,
          onPressed: onRemove,
          icon: const Icon(Icons.close, size: 18),
          color: AppTokens.inkMuted,
        ),
      ],
    );
  }
}
