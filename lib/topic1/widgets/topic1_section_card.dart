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
        backgroundColor: AppTokens.ink,
        disabledBackgroundColor: AppTokens.surfaceMuted,
        foregroundColor: Colors.white,
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

/// The small "1", "2", … badge and remove button that start every row.
class Topic1RowHeader extends StatelessWidget {
  /// Position of the row, from 0.
  final int index;

  /// Key of the remove button.
  final Key removeKey;

  /// Removes the row; null disables the button.
  final VoidCallback? onRemove;

  /// Tooltip of the remove button.
  final String removeTooltip;

  const Topic1RowHeader({
    required this.index,
    required this.removeKey,
    required this.onRemove,
    required this.removeTooltip,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
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
        const Spacer(),
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
