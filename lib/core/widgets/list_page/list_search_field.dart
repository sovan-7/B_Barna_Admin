import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

/// The compact search box above every list: a search icon, a text field
/// and — once something is typed — a clear (×) button.
///
/// It holds no state of its own. The screen owns [controller] and gets a
/// callback on every change / clear, so it can pass the text to its view
/// model and `setState` (which also refreshes the clear button and the
/// empty-state wording).
class ListSearchField extends StatelessWidget {
  /// Holds the typed text. Owned (and disposed) by the screen.
  final TextEditingController controller;

  /// Placeholder, e.g. "Search by PDF code".
  final String hintText;

  /// Called after every keystroke with the new text.
  final ValueChanged<String> onChanged;

  /// Called after the × button has cleared the field.
  final VoidCallback onCleared;

  /// Widest the box may grow (it shrinks on narrow windows).
  final double maxWidth;

  const ListSearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onCleared,
    this.maxWidth = 380,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasText = controller.text.isNotEmpty;

    return Container(
      height: 40,
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppTokens.hairline),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 17, color: AppTokens.inkFaint),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(fontSize: 13, color: AppTokens.ink),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hintText,
                hintStyle:
                    const TextStyle(fontSize: 13, color: AppTokens.inkFaint),
              ),
              onChanged: (_) => onChanged(controller.text),
            ),
          ),
          // Clear button, only once there is something to clear.
          if (hasText)
            InkWell(
              onTap: () {
                controller.clear();
                onCleared();
              },
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close, size: 16, color: AppTokens.inkMuted),
              ),
            ),
        ],
      ),
    );
  }
}
