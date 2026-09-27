import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

/// The bar pinned to the bottom of a form: Delete (edit mode only) on the
/// left, then Cancel and the save button on the right.
///
/// Below 560px the delete button shrinks to an icon and the save button
/// stretches to fill the row.
class FormActionBar extends StatelessWidget {
  /// Window width.
  final double width;

  /// True while saving/deleting: every button is disabled.
  final bool isSaving;

  /// Shows the delete button when non-null (edit mode).
  final VoidCallback? onDelete;

  /// Tooltip of the icon-only delete button, e.g. "Delete course".
  final String deleteTooltip;

  /// Key of the save button (tests tap it), e.g. `course_save_button`.
  final Key saveKey;

  /// e.g. "Save course" / "Update course".
  final String saveLabel;

  final VoidCallback onSave;

  /// Minimum width of the save button.
  final double saveMinWidth;

  /// Should match the page's content width.
  final double maxWidth;

  const FormActionBar({
    required this.width,
    required this.isSaving,
    required this.saveKey,
    required this.saveLabel,
    required this.onSave,
    this.onDelete,
    this.deleteTooltip = "Delete",
    this.saveMinWidth = 140,
    this.maxWidth = 720,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bool narrow = width < 560;
    final VoidCallback? onDelete = this.onDelete;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: formPagePadding(width), vertical: 14),
      decoration: const BoxDecoration(
        color: AppTokens.surface,
        border: Border(top: BorderSide(color: AppTokens.hairline)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Row(
            children: [
              if (onDelete != null)
                narrow
                    ? IconButton(
                        onPressed: isSaving ? null : onDelete,
                        tooltip: deleteTooltip,
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: AppTokens.danger,
                      )
                    : TextButton.icon(
                        onPressed: isSaving ? null : onDelete,
                        icon: const Icon(Icons.delete_outline, size: 17),
                        label: const Text("Delete"),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTokens.danger,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                        ),
                      ),
              if (!narrow) const Spacer(),
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppTokens.inkMuted,
                  padding: EdgeInsets.symmetric(
                      horizontal: narrow ? 12 : 18, vertical: 14),
                ),
                child: const Text("Cancel"),
              ),
              const SizedBox(width: AppTokens.gapSm),
              _saveButton(expand: narrow),
            ],
          ),
        ),
      ),
    );
  }

  /// Dark primary button; shows a spinner while [isSaving].
  Widget _saveButton({required bool expand}) {
    final Widget button = ConstrainedBox(
      constraints: BoxConstraints(minWidth: saveMinWidth, minHeight: 42),
      child: ElevatedButton(
        key: saveKey,
        onPressed: isSaving ? null : onSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTokens.ink,
          disabledBackgroundColor: AppTokens.ink.withValues(alpha: .55),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
        ),
        child: isSaving
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: Colors.white),
              )
            : Text(saveLabel,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600)),
      ),
    );

    return expand ? Expanded(child: button) : button;
  }
}
