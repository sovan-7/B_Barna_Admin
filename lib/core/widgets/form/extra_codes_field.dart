import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/utils/formatters.dart';
import 'package:flutter/material.dart';

/// "Also appears in": a growable list of extra parent codes for an item
/// that is shared (a unit shown under several subjects, a topic under
/// several units). One upper-casing text box per code with a remove (×)
/// button, and an "Add a … code" button underneath.
///
/// The list of controllers is owned by the form; [onAdd] / [onRemove] let
/// it add or dispose one inside its own `setState`.
class ExtraCodesField extends StatelessWidget {
  /// One controller per code box.
  final List<TextEditingController> controllers;

  /// Help text under the label.
  final String description;

  /// Placeholder in each box, e.g. "Subject code".
  final String hint;

  /// Text of the add button, e.g. "Add a subject code".
  final String addLabel;

  /// Buttons are keyed `<keyPrefix>_extra_code_add` and
  /// `<keyPrefix>_extra_code_remove_<index>`.
  final String keyPrefix;

  /// False while saving.
  final bool enabled;

  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const ExtraCodesField({
    required this.controllers,
    required this.description,
    required this.hint,
    required this.addLabel,
    required this.keyPrefix,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Also appears in", style: AppTokens.fieldLabel),
        const SizedBox(height: 2),
        Text(
          description,
          style: const TextStyle(
              fontSize: 11.5, height: 1.35, color: AppTokens.inkFaint),
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < controllers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.gapSm),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTokens.surface,
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      border: Border.all(color: AppTokens.hairline),
                    ),
                    child: TextField(
                      controller: controllers[i],
                      inputFormatters: [UpperCaseTextFormatter()],
                      style:
                          const TextStyle(fontSize: 13.5, color: AppTokens.ink),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: hint,
                        hintStyle: const TextStyle(
                            fontSize: 13, color: AppTokens.inkFaint),
                        contentPadding:
                            const EdgeInsets.fromLTRB(14, 13, 14, 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.gapSm),
                IconButton(
                  key: Key('${keyPrefix}_extra_code_remove_$i'),
                  tooltip: "Remove this code",
                  onPressed: enabled ? () => onRemove(i) : null,
                  icon: const Icon(Icons.close, size: 18),
                  color: AppTokens.inkMuted,
                ),
              ],
            ),
          ),
        TextButton.icon(
          key: Key('${keyPrefix}_extra_code_add'),
          onPressed: enabled ? onAdd : null,
          icon: const Icon(Icons.add, size: 16),
          label: Text(addLabel, style: const TextStyle(fontSize: 12.5)),
          style: TextButton.styleFrom(
            foregroundColor: AppTokens.inkMuted,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
        ),
      ],
    );
  }
}
