// ignore_for_file: must_be_immutable

import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/login/screen/login_screen.dart';
import 'package:bbarna/resources/app_colors.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/session.dart';
import 'package:flutter/material.dart';

/// The white top bar of every page: menu button (compact windows only),
/// brand mark, app name, the current page title, and sign-out.
class AppHeader extends StatelessWidget {
  /// Opens the navigation drawer (compact windows).
  Function onTapIcon;

  /// Shown next to the app name — the page you are on.
  final String? title;

  AppHeader({required this.onTapIcon, this.title, super.key});

  @override
  Widget build(BuildContext context) {
    // The menu button opens the drawer, which only exists below the
    // breakpoint, so it is hidden on wide windows.
    final bool showMenuButton =
        MediaQuery.sizeOf(context).width < AppTokens.compactBreakpoint;

    return Container(
      height: AppTokens.headerHeight,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: AppTokens.surface,
        border: Border(bottom: BorderSide(color: AppTokens.hairline)),
      ),
      child: Row(
        children: [
          if (showMenuButton) ...[
            _iconButton(
              icon: Icons.menu,
              tooltip: "Open navigation",
              color: AppTokens.inkMuted,
              onTap: () => onTapIcon(),
            ),
            const SizedBox(width: AppTokens.gapSm),
          ],
          // One Expanded for everything on the left, rather than a
          // Flexible title plus a Spacer: those are both flex:1, so they
          // split the free space evenly and the trailing icon ends up
          // floating in the middle of the bar instead of at its edge.
          Expanded(
            child: Row(
              children: [
                Container(
                  height: 26,
                  width: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColorsInApp.colorLightBlue,
                    borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                  ),
                  // Ink, not white: white on this cyan is about 1.7:1.
                  child: const Text(
                    "B",
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTokens.ink),
                  ),
                ),
                const SizedBox(width: 10),
                // Flexible with an ellipsis as a backstop: the app name is
                // the one thing here with no length limit at all if it is
                // ever reworded.
                const Flexible(
                  child: Text(
                    "Admin Portal",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: AppTokens.ink),
                  ),
                ),
                // The breadcrumb is dropped on a phone, where it competes
                // with the app name for a bar that is already carrying two
                // buttons — and where the page's own title is right below
                // it anyway.
                if (title != null && !showMenuButton) ...[
                  const SizedBox(width: 10),
                  const Text("/",
                      style:
                          TextStyle(fontSize: 14, color: AppTokens.inkFaint)),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      title!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, color: AppTokens.inkMuted),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _iconButton(
            key: const Key('app_header_sign_out'),
            icon: Icons.logout_rounded,
            tooltip: "Sign out",
            color: AppColorsInApp.colorPrimary,
            onTap: () => _confirmSignOut(context),
          ),
        ],
      ),
    );
  }

  /// A small square icon button with a tooltip.
  Widget _iconButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback? onTap,
    Key? key,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }

  /// Asks first, because this button sits one tap away on every page —
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
        // RemoveAlert never closes itself.
        Navigator.pop(navigatorKey.currentContext!);
        await Session.signOut();

        // pushAndRemoveUntil, not push: everything the signed-out admin was
        // looking at has to come off the stack, or the browser's back
        // button walks straight back into it.
        await navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      },
    );
  }
}
