// ignore_for_file: must_be_immutable

import 'package:bbarna/core/widgets/brand_mark.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/login/screen/login_screen.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/session.dart';
import 'package:flutter/material.dart';

/// The slim white bar above every page: a breadcrumb ("Content › Courses")
/// on wide windows, the menu button and brand on compact ones, and the
/// account chip whose menu holds Sign out.
///
/// The brand lives on the rail beside it, so the bar does not repeat it
/// unless the rail is folded away into a drawer.
class AppHeader extends StatelessWidget {
  /// Opens the navigation drawer (compact windows).
  Function onTapIcon;

  /// The module the page belongs to: its group and name lead the
  /// breadcrumb.
  final int? moduleIndex;

  /// The page you are on, after the module in the breadcrumb ("Courses",
  /// "Add a course"). Left out when it only repeats the module's name.
  final String? title;

  AppHeader({required this.onTapIcon, this.moduleIndex, this.title, super.key});

  /// Breadcrumb parts, outermost first.
  List<String> get _crumbs {
    final int? index = moduleIndex;
    final List<String> crumbs = [];
    if (index != null && index >= 0 && index < moduleDisplayList.length) {
      final ModuleGroup? group = groupOfModule(index);
      if (group != null) crumbs.add(group.label);
      crumbs.add(moduleDisplayList[index]);
    }
    final String? page = title?.trim();
    if (page != null && page.isNotEmpty && !crumbs.contains(page)) {
      crumbs.add(page);
    }
    return crumbs;
  }

  @override
  Widget build(BuildContext context) {
    // The menu button opens the drawer, which only exists below the
    // breakpoint, so it is hidden on wide windows.
    final bool isCompact =
        MediaQuery.sizeOf(context).width < AppTokens.compactBreakpoint;
    final List<String> crumbs = _crumbs;

    return Container(
      height: AppTokens.headerHeight,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppTokens.surface,
        border: Border(bottom: BorderSide(color: AppTokens.hairline)),
      ),
      child: Row(
        children: [
          if (isCompact) ...[
            Tooltip(
              message: "Open navigation",
              child: InkWell(
                onTap: () => onTapIcon(),
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                child: const Padding(
                  padding: EdgeInsets.all(7),
                  child: Icon(Icons.menu, size: 20, color: AppTokens.inkMuted),
                ),
              ),
            ),
            const SizedBox(width: AppTokens.gapSm),
            const BrandMark(size: 26),
            const SizedBox(width: 10),
          ],
          // One Expanded for everything on the left, so the account chip
          // stays pinned to the right edge.
          Expanded(child: _breadcrumb(crumbs, isCompact)),
          const SizedBox(width: AppTokens.gapSm),
          _AccountMenu(onSignOut: () => _confirmSignOut(context)),
        ],
      ),
    );
  }

  /// "Group › Module › Page". On a phone only the last part is shown — the
  /// bar is narrow and the page's own title is right below it anyway.
  Widget _breadcrumb(List<String> crumbs, bool isCompact) {
    if (crumbs.isEmpty) {
      return const Text("Admin portal",
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppTokens.ink));
    }
    final List<String> shown = isCompact ? [crumbs.last] : crumbs;

    final List<Widget> parts = [];
    for (int i = 0; i < shown.length; i++) {
      final bool last = i == shown.length - 1;
      if (i > 0) {
        parts.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.chevron_right, size: 16, color: AppTokens.inkFaint),
        ));
      }
      parts.add(Flexible(
        child: Text(
          shown[i],
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 13.5,
              fontWeight: last ? FontWeight.w600 : FontWeight.w400,
              color: last ? AppTokens.ink : AppTokens.inkFaint),
        ),
      ));
    }
    return Row(children: parts);
  }

  /// Asks first, because Sign out sits one click away on every page —
  /// including halfway through an add/edit form, where signing out throws
  /// the unsaved work away.
  ///
  /// Uses the same [RemoveAlert] every destructive action in the app goes
  /// through, so the confirmation looks the same wherever it appears.
  void _confirmSignOut(BuildContext context) {
    // Captured before the alert: the header's own element is gone by the
    // time the route is replaced.
    final NavigatorState navigator = Navigator.of(context, rootNavigator: true);

    RemoveAlert.showRemoveAlert(
      title: "Sign out",
      description: "Are you sure want to sign out ?",
      confirmLabel: "Sign out",
      onPressYes: () async {
        // RemoveAlert never closes itself: it stays open, its button
        // spinning, while signing out, and goes with everything else below.
        await Session.signOut();

        // pushAndRemoveUntil, not push: everything the signed-out admin was
        // looking at (this dialog included) has to come off the stack, or
        // the browser's back button walks straight back into it.
        await navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      },
    );
  }
}

/// The round initial and role ("Admin" / "Sub-admin") at the right of the
/// header. Its menu says what the account can reach and holds Sign out.
class _AccountMenu extends StatelessWidget {
  /// Starts signing out (with its confirmation).
  final VoidCallback onSignOut;

  const _AccountMenu({required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = Session.isAdmin;
    final String role = isAdmin ? "Admin" : "Sub-admin";
    final bool isCompact =
        MediaQuery.sizeOf(context).width < AppTokens.compactBreakpoint;

    return PopupMenuButton<String>(
      key: const Key('app_header_account'),
      tooltip: "Account",
      offset: const Offset(0, AppTokens.headerHeight - 8),
      color: AppTokens.surface,
      surfaceTintColor: AppTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        side: const BorderSide(color: AppTokens.hairline),
      ),
      onSelected: (value) {
        if (value == 'sign_out') onSignOut();
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          height: 44,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Signed in as $role",
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.ink)),
              Text(isAdmin ? "Full access" : "Assigned modules only",
                  style:
                      const TextStyle(fontSize: 12, color: AppTokens.inkMuted)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem<String>(
          key: Key('app_header_sign_out'),
          value: 'sign_out',
          height: 40,
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18, color: AppTokens.danger),
              SizedBox(width: 10),
              Text("Sign out",
                  style: TextStyle(fontSize: 13.5, color: AppTokens.danger)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(3, 3, 10, 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          border: Border.all(color: AppTokens.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 26,
              width: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  color: AppTokens.accentTint, shape: BoxShape.circle),
              child: Text(role[0],
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.accent)),
            ),
            if (!isCompact) ...[
              const SizedBox(width: 8),
              Text(role,
                  style: const TextStyle(fontSize: 12.5, color: AppTokens.ink)),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down,
                size: 16, color: AppTokens.inkFaint),
          ],
        ),
      ),
    );
  }
}
