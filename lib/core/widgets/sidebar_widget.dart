import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

/// One row of the navy navigation rail: icon and label in a rounded item.
/// The selected module is a solid accent pill; hover lifts the row to the
/// raised navy.
class SidebarWidget extends StatefulWidget {
  /// Module icon.
  final IconData iconData;

  /// Module label.
  final String itemText;

  /// Highlights the item.
  final bool isSelected;

  /// Opens the module.
  final VoidCallback? onTap;

  /// Icon-only mode for the narrow rail. The label becomes a tooltip.
  final bool isCollapsed;

  const SidebarWidget({
    required this.iconData,
    required this.itemText,
    required this.isSelected,
    this.onTap,
    this.isCollapsed = false,
    super.key,
  });

  @override
  State<SidebarWidget> createState() => _SidebarWidgetState();
}

class _SidebarWidgetState extends State<SidebarWidget> {
  /// True while the pointer is over the item.
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool selected = widget.isSelected;

    final Color background = selected
        ? AppTokens.accent
        : _hovered
            ? AppTokens.brandNavyRaised
            : Colors.transparent;
    final Color foreground = selected ? Colors.white : AppTokens.onNavy;

    final Widget row = Row(
      mainAxisAlignment: widget.isCollapsed
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        // The icon sits a step back from the label so the row reads
        // label-first, except on the selected row where both are white.
        Icon(widget.iconData,
            size: 18,
            color: selected || _hovered ? foreground : AppTokens.onNavyMuted),
        if (!widget.isCollapsed) ...[
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              widget.itemText,
              overflow: TextOverflow.ellipsis,
              style: selected
                  ? AppTokens.navItemSelected.copyWith(color: foreground)
                  : AppTokens.navItem.copyWith(color: foreground),
            ),
          ),
        ],
      ],
    );

    final Widget item = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: widget.isCollapsed ? 10 : 10, vertical: 1),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: 36,
              padding:
                  EdgeInsets.symmetric(horizontal: widget.isCollapsed ? 0 : 10),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              ),
              child: row,
            ),
          ),
        ),
      ),
    );

    // Collapsed, the icon is the only label there is.
    return widget.isCollapsed
        ? Tooltip(
            message: widget.itemText,
            waitDuration: const Duration(milliseconds: 300),
            child: item,
          )
        : item;
  }
}
