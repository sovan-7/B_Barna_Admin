import 'package:bbarna/core/widgets/form/admin_form_scaffold.dart';
import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/topic/model/topic_model.dart';
import 'package:bbarna/topic/viewModel/topic_view_model.dart';
import 'package:bbarna/topic/widgets/topic_content_section.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Everything attached to one topic: its videos, audio, PDFs and quizzes,
/// one editable section per kind (see [TopicContentSection]).
class TopicDetails extends StatefulWidget {
  /// The topic whose content is managed.
  final TopicModel topicData;
  const TopicDetails({required this.topicData, super.key});

  @override
  State<TopicDetails> createState() => _TopicDetailsState();
}

class _TopicDetailsState extends State<TopicDetails> {
  /// `code -> title` per kind, so each row can say what it points at.
  /// Absent means "still loading".
  final Map<ContentKind, Map<String, String>> _titles = {};

  /// Kinds whose lookup failed: their rows say the code couldn't be
  /// checked, rather than that it points at nothing.
  final Set<ContentKind> _checkFailed = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveAll());
  }

  /// Looks up titles for every kind's codes (all kinds at once).
  Future<void> _resolveAll() async {
    await Future.wait([
      for (final ContentKind kind in ContentKind.values)
        _resolve(kind, widget.topicData.contentCodes(kind)),
    ]);
  }

  /// Looks up which of [codes] exist and stores their titles.
  Future<void> _resolve(ContentKind kind, List<String> codes) async {
    if (!mounted) return;
    final TopicViewModel topicViewModel =
        Provider.of<TopicViewModel>(context, listen: false);
    setState(() => _checkFailed.remove(kind));
    final Map<String, String>? resolved =
        await topicViewModel.resolveContentTitles(kind, codes);
    if (!mounted) return;
    setState(() {
      if (resolved == null) {
        _titles.remove(kind);
        _checkFailed.add(kind);
      } else {
        _titles[kind] = resolved;
      }
    });
  }

  /// Saves one kind's codes, then re-checks what they point at.
  Future<bool> _save(TopicViewModel topicViewModel, ContentKind kind,
      List<String> codes) async {
    final bool ok =
        await topicViewModel.saveContentCodes(widget.topicData, kind, codes);
    if (!ok) return false;

    Helper.showSnackBarMessage(
        msg: "${kind.label} codes saved", isSuccess: true);
    // Re-check what the newly saved codes point at (the rows stay on screen).
    await _resolve(kind, codes);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormScaffold(
      headerTitle: "Topics",
      sidebarIndex: 4,
      body: (context, width) => Consumer<TopicViewModel>(
        builder: (context, topicViewModel, child) =>
            _page(topicViewModel, width),
      ),
    );
  }

  /// Header, then one [TopicContentSection] per kind of content.
  Widget _page(TopicViewModel topicViewModel, double width) {
    return FormPageBody(
      width: width,
      children: [
        _pageHeader(),
        const SizedBox(height: AppTokens.gapLg),
        for (final ContentKind kind in ContentKind.values)
          TopicContentSection(
            // Keyed by kind so each section keeps its own rows.
            key: ValueKey(kind),
            kind: kind,
            initialCodes: widget.topicData.contentCodes(kind),
            titles: _titles[kind],
            checkFailed: _checkFailed.contains(kind),
            onRecheck: (codes) => _resolve(kind, codes),
            onSave: (codes) => _save(topicViewModel, kind, codes),
          ),
        const SizedBox(height: AppTokens.gapLg),
      ],
    );
  }

  /// Back button, title and subtitle at the top of the page.
  Widget _pageHeader() {
    final TopicModel data = widget.topicData;
    String or(String value, String fallback) =>
        value.isEmpty || value == stringDefault ? fallback : value;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormBackButton(onTap: () => Navigator.pop(context)),
        const SizedBox(width: AppTokens.gapMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(or(data.name, "Topic"),
                        overflow: TextOverflow.ellipsis,
                        style: AppTokens.pageTitle),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTokens.surface,
                      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                      border: Border.all(color: AppTokens.hairline),
                    ),
                    child: Text(data.code,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: AppTokens.inkMuted)),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              // The topic's own name as the page heading.
              Text(
                "${or(data.courseName, 'No course')}  ›  "
                "${or(data.subjectName, 'No subject')}  ›  "
                "${or(data.unitName, 'No unit')}",
                overflow: TextOverflow.ellipsis,
                style: AppTokens.pageSubtitle,
              ),
              const SizedBox(height: 3),
              const Text(
                  "Attach content by its code. Each list saves on its own.",
                  style: TextStyle(fontSize: 12, color: AppTokens.inkFaint)),
            ],
          ),
        ),
      ],
    );
  }
}
