import 'package:bbarna/core/widgets/app_header.dart';
import 'package:bbarna/core/widgets/sidebar.dart';
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
  final TopicModel topicData;
  const TopicDetails({required this.topicData, super.key});

  @override
  State<TopicDetails> createState() => _TopicDetailsState();
}

class _TopicDetailsState extends State<TopicDetails> {
  final GlobalKey<ScaffoldState> key = GlobalKey();

  /// `code -> title` per kind, so each row can say what it points at.
  /// Absent means "still loading".
  final Map<ContentKind, Map<String, String>> _titles = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveAll());
  }

  Future<void> _resolveAll() async {
    for (final ContentKind kind in ContentKind.values) {
      await _resolve(kind, widget.topicData.contentCodes(kind));
    }
  }

  Future<void> _resolve(ContentKind kind, List<String> codes) async {
    if (!mounted) return;
    final TopicViewModel topicViewModel =
        Provider.of<TopicViewModel>(context, listen: false);
    final Map<String, String> resolved =
        await topicViewModel.resolveContentTitles(kind, codes);
    if (!mounted) return;
    setState(() => _titles[kind] = resolved);
  }

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
    final double width = MediaQuery.of(context).size.width;
    final bool isCompact = width < AppTokens.compactBreakpoint;

    return Scaffold(
      key: key,
      backgroundColor: AppTokens.canvas,
      body: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
        },
        child: Column(
          children: [
            AppHeader(
              onTapIcon: () => key.currentState?.openDrawer(),
              title: "Topics",
            ),
            Expanded(
              child: Row(
                children: [
                  if (!isCompact)
                    const Expanded(child: ExtraSideBar(sidebarIndex: 4)),
                  Expanded(
                    flex: 5,
                    child: Consumer<TopicViewModel>(
                      builder: (context, topicViewModel, child) =>
                          _page(topicViewModel, width),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      drawer:
          isCompact ? const Drawer(child: ExtraSideBar(sidebarIndex: 4)) : null,
    );
  }

  Widget _page(TopicViewModel topicViewModel, double width) {
    return SingleChildScrollView(
      padding:
          EdgeInsets.symmetric(horizontal: width < 700 ? 16 : 32, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  onSave: (codes) => _save(topicViewModel, kind, codes),
                ),
              const SizedBox(height: AppTokens.gapLg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageHeader() {
    final TopicModel data = widget.topicData;
    String or(String value, String fallback) =>
        value.isEmpty || value == stringDefault ? fallback : value;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _backButton(),
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

  Widget _backButton() {
    return Material(
      color: AppTokens.surface,
      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      child: InkWell(
        onTap: () => Navigator.pop(context),
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
