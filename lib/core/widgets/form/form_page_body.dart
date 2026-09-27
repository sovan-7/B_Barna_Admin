import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

/// Horizontal page padding: tighter on phones.
double formPagePadding(double width) => width < 700 ? 16 : 32;

/// A form page's scrolling content plus the action bar pinned below it.
///
/// [children] (header, sections, …) are centred in a column at most
/// [maxWidth] wide and scroll; [actionBar] stays at the bottom.
class FormPageBody extends StatelessWidget {
  /// Window width, for the side padding.
  final double width;

  /// The page sections, top to bottom.
  final List<Widget> children;

  /// Usually a [FormActionBar]; nothing when null.
  final Widget? actionBar;

  /// Widest the content column may grow.
  final double maxWidth;

  const FormPageBody({
    required this.width,
    required this.children,
    this.actionBar,
    this.maxWidth = 720,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
                horizontal: formPagePadding(width), vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
          ),
        ),
        if (actionBar != null) actionBar!,
      ],
    );
  }
}

/// Title row at the top of a form page: a back button, then the title and a
/// one-line subtitle.
class FormPageHeader extends StatelessWidget {
  /// e.g. "Add a course" / "Edit course".
  final String title;

  /// One line under the title.
  final String subtitle;

  /// Back button action; null disables it (e.g. while saving).
  final VoidCallback? onBack;

  const FormPageHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormBackButton(onTap: onBack),
        const SizedBox(width: AppTokens.gapMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTokens.pageTitle),
              const SizedBox(height: 3),
              Text(subtitle, style: AppTokens.pageSubtitle),
            ],
          ),
        ),
      ],
    );
  }
}

/// The square outlined ← button at the top-left of a form page.
class FormBackButton extends StatelessWidget {
  /// What tapping does (usually `Navigator.pop`); null disables it.
  final VoidCallback? onTap;

  const FormBackButton({required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTokens.surface,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            border: Border.all(color: AppTokens.hairline),
          ),
          child: const Icon(Icons.arrow_back, size: 18, color: AppTokens.ink),
        ),
      ),
    );
  }
}

/// A white card grouping related fields under an upper-case [title]
/// (e.g. "COURSE DETAILS"), with an optional [trailing] widget on the
/// title row.
class FormSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  /// Shown at the right end of the title row (e.g. a count or a button).
  final Widget? trailing;

  const FormSection({
    required this.title,
    required this.children,
    this.trailing,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final Widget? trailing = this.trailing;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppTokens.hairline),
        boxShadow: AppTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trailing == null)
            Text(title, style: AppTokens.sectionTitle)
          else
            Row(
              children: [
                Text(title, style: AppTokens.sectionTitle),
                const Spacer(),
                trailing,
              ],
            ),
          const SizedBox(height: AppTokens.gapMd),
          ...children,
        ],
      ),
    );
  }
}

/// Two fields side by side on wide windows, stacked on narrow ones
/// (below [breakpoint]).
class FormTwoUp extends StatelessWidget {
  /// Window width.
  final double width;
  final Widget left;
  final Widget right;

  /// Below this width the fields stack.
  final double breakpoint;

  const FormTwoUp({
    required this.width,
    required this.left,
    required this.right,
    this.breakpoint = 700,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (width < breakpoint) {
      return Column(children: [
        left,
        const SizedBox(height: AppTokens.gapMd),
        right,
      ]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: AppTokens.gapMd),
        Expanded(child: right),
      ],
    );
  }
}
