import 'package:bbarna/core/widgets/form/form_dirty_scope.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

/// Horizontal page padding: tighter on phones.
double formPagePadding(double width) => width < 700 ? 16 : 32;

/// A form page's scrolling content plus the action bar pinned below it.
///
/// [children] (header, sections, …) are centred in a column at most
/// [maxWidth] wide and scroll; [actionBar] stays at the bottom. Both sit
/// in a [FormDirtyScope], so the shared fields can tell the action bar
/// that something has changed.
class FormPageBody extends StatefulWidget {
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
  State<FormPageBody> createState() => _FormPageBodyState();
}

class _FormPageBodyState extends State<FormPageBody> {
  /// Whether anything on this page has been changed.
  final FormDirtyController _dirty = FormDirtyController();

  @override
  void dispose() {
    _dirty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget? actionBar = widget.actionBar;
    return FormDirtyScope(
      controller: _dirty,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                  horizontal: formPagePadding(widget.width), vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: widget.maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.children,
                  ),
                ),
              ),
            ),
          ),
          if (actionBar != null) actionBar,
        ],
      ),
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

/// A white card grouping related fields under a [title] with a small
/// icon (e.g. "Course details"), with an optional [trailing] widget on the
/// title row.
///
/// Titles may be written upper-case ("COURSE DETAILS"); they are shown in
/// sentence case, acronyms such as PDF kept.
class FormSection extends StatelessWidget {
  /// Section heading, e.g. "COURSE DETAILS".
  final String title;

  /// The fields in the section.
  final List<Widget> children;

  /// Shown at the right end of the title row (e.g. a count or a button).
  final Widget? trailing;

  /// Icon before the title; picked from the title's words when null.
  final IconData? icon;

  const FormSection({
    required this.title,
    required this.children,
    this.trailing,
    this.icon,
    super.key,
  });

  /// Words kept as written rather than lower-cased.
  static const Map<String, String> _keepCase = {
    "PDF": "PDF",
    "PDFS": "PDFs",
    "URL": "URL",
    "ID": "ID",
    "YOUTUBE": "YouTube",
    "WHATSAPP": "WhatsApp",
  };

  /// "COURSE DETAILS" → "Course details"; mixed-case titles are left alone.
  static String sentenceCase(String title) {
    if (title != title.toUpperCase()) return title;
    final List<String> words = title.toLowerCase().split(' ');
    for (int i = 0; i < words.length; i++) {
      final String bare = words[i].replaceAll(RegExp(r'[^a-z]'), '');
      final String? kept = _keepCase[bare.toUpperCase()];
      if (kept != null) {
        words[i] = words[i].replaceFirst(bare, kept);
      } else if (i == 0 && words[i].isNotEmpty) {
        words[i] = words[i][0].toUpperCase() + words[i].substring(1);
      }
    }
    return words.join(' ');
  }

  /// An icon that fits the title's words, or a neutral one.
  static IconData iconFor(String title) {
    final String t = title.toUpperCase();
    bool has(String word) => t.contains(word);
    if (has("IMAGE") || has("PICTURE") || has("COVER")) {
      return Icons.image_outlined;
    }
    if (has("AVAILABILITY") || has("VISIB")) return Icons.visibility_outlined;
    if (has("PRICE") || has("PRICING")) return Icons.currency_rupee;
    if (has("COUPON")) return Icons.local_offer_outlined;
    if (has("WHERE") || has("BELONG")) return Icons.account_tree_outlined;
    if (has("ACCESS") || has("ROLE")) return Icons.lock_outline;
    if (has("ACCOUNT")) return Icons.person_outline;
    if (has("FILE") || has("PDF")) return Icons.attach_file;
    if (has("LINK") || has("VIDEO")) return Icons.link;
    if (has("AUDIO")) return Icons.headphones_outlined;
    if (has("QUESTION")) return Icons.help_outline;
    if (has("ANSWER")) return Icons.lightbulb_outline;
    if (has("RULES")) return Icons.rule;
    if (has("CONTENT")) return Icons.layers_outlined;
    if (has("ENROL")) return Icons.school_outlined;
    if (has("MESSAGE")) return Icons.chat_bubble_outline;
    if (has("SCHEDULE") || has("TIME") || has("WHEN")) return Icons.schedule;
    return Icons.notes_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final Widget? trailing = this.trailing;
    final Widget heading = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon ?? iconFor(title), size: 16, color: AppTokens.inkMuted),
        const SizedBox(width: 8),
        Flexible(
          child: Text(sentenceCase(title),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.ink)),
        ),
      ],
    );
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
            heading
          else
            Row(
              children: [
                Flexible(child: heading),
                const SizedBox(width: AppTokens.gapSm),
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

  /// First field (left, or top when stacked).
  final Widget left;

  /// Second field (right, or bottom when stacked).
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
