import 'package:bbarna/core/widgets/app_header.dart';
import 'package:bbarna/core/widgets/sidebar.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

/// The frame around every Add/Edit page: the navy module rail on the left
/// (or in a drawer below [AppTokens.compactBreakpoint]) with [sidebarIndex]
/// highlighted, the [AppHeader] breadcrumb, and [body] filling the rest.
///
/// [body] is built with the window width so the page can adapt its own
/// layout (stacked fields, narrower padding, …).
class AdminFormScaffold extends StatefulWidget {
  /// Text in the header bar, e.g. "Courses".
  final String headerTitle;

  /// Index of the module in the sidebar to highlight.
  final int sidebarIndex;

  /// Builds the page content for the current window width.
  final Widget Function(BuildContext context, double width) body;

  /// Canvas colour behind the page.
  final Color backgroundColor;

  const AdminFormScaffold({
    required this.headerTitle,
    required this.sidebarIndex,
    required this.body,
    this.backgroundColor = AppTokens.canvas,
    super.key,
  });

  @override
  State<AdminFormScaffold> createState() => _AdminFormScaffoldState();
}

class _AdminFormScaffoldState extends State<AdminFormScaffold> {
  /// Lets the header's menu button open the drawer on compact screens.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool isCompact = width < AppTokens.compactBreakpoint;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: widget.backgroundColor,
      body: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
        },
        child: Row(
          children: [
            // The same rail as the list screens on wide windows, in a
            // drawer otherwise.
            if (!isCompact)
              ExtraSideBar(sidebarIndex: widget.sidebarIndex, inline: true),
            Expanded(
              child: Column(
                children: [
                  AppHeader(
                    onTapIcon: () => _scaffoldKey.currentState?.openDrawer(),
                    moduleIndex: widget.sidebarIndex,
                    title: widget.headerTitle,
                  ),
                  Expanded(child: widget.body(context, width)),
                ],
              ),
            ),
          ],
        ),
      ),
      drawer: isCompact
          ? Drawer(
              width: AppTokens.railWidth,
              backgroundColor: AppTokens.railBackground,
              child: ExtraSideBar(sidebarIndex: widget.sidebarIndex))
          : null,
    );
  }
}
