import 'package:bbarna/core/widgets/card/image_or_initial.dart';
import 'package:bbarna/core/widgets/selectable_label.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:flutter/material.dart';

/// The first cell of an [AdminTable] row: a small picture (or an icon, or
/// the item's initial), its name, and one muted line under it.
class TableIdentity extends StatelessWidget {
  /// The item's name (selectable, for copying).
  final String title;

  /// One line under the name, or nothing when blank.
  final String? subtitle;

  /// Picture URL; the [initial] shows when it is blank or fails to load.
  final String? imageUrl;

  /// Letter shown instead of a picture.
  final String initial;

  /// An icon tile instead of a picture (media rows).
  final IconData? icon;

  /// Tint behind [icon].
  final Color? iconColor;

  const TableIdentity({
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.initial = "?",
    this.icon,
    this.iconColor,
    super.key,
  });

  /// Whether [value] carries real text (not blank, not a `*Default`).
  static bool hasText(String? value) =>
      value != null && value.trim().isNotEmpty && value != stringDefault;

  @override
  Widget build(BuildContext context) {
    final Widget leading = icon != null
        ? Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: (iconColor ?? AppTokens.inkMuted).withValues(alpha: .10),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            ),
            child: Icon(icon, size: 18, color: iconColor ?? AppTokens.inkMuted),
          )
        : ImageOrInitial(
            imageUrl: imageUrl ?? "",
            initial: initial,
            size: 34,
            fontSize: 13,
          );

    return Row(
      children: [
        leading,
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableLabel(
                hasText(title) ? title : "Untitled",
                maxLines: 1,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.ink),
              ),
              if (hasText(subtitle)) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppTokens.inkMuted)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Plain muted text for a table cell, or a dash when there is none.
class TableText extends StatelessWidget {
  /// The value.
  final String? text;

  /// Bolder, ink-coloured (e.g. an amount).
  final bool strong;

  const TableText(this.text, {this.strong = false, super.key});

  @override
  Widget build(BuildContext context) {
    final bool has = TableIdentity.hasText(text);
    return Text(has ? text! : "—",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: 12.5,
            fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
            color: !has
                ? AppTokens.inkFaint
                : strong
                    ? AppTokens.ink
                    : AppTokens.inkMuted));
  }
}
