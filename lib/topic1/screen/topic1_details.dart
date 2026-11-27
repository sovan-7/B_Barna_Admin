import 'package:bbarna/core/widgets/form/admin_form_scaffold.dart';
import 'package:bbarna/core/widgets/form/form_page_body.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/topic/model/topic_model.dart';
import 'package:bbarna/topic/widgets/topic_content_section.dart';
import 'package:bbarna/topic1/model/topic1_model.dart';
import 'package:bbarna/topic1/viewModel/topic1_view_model.dart';
import 'package:bbarna/topic1/widgets/topic1_pdf_section.dart';
import 'package:bbarna/topic1/widgets/topic1_video_section.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:bbarna/topic/widgets/content_tabs.dart';
import 'package:bbarna/topic1/screen/edit_topic1.dart';
import 'package:bbarna/utils/navigation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Everything on one Topic1: uploaded PDFs ([Topic1PdfSection]), YouTube
/// videos ([Topic1VideoSection]), and audio and quizzes attached by code
/// exactly as on a topic ([TopicContentSection]). Each list saves on its
/// own.
class Topic1Details extends StatefulWidget {
  /// The topic whose content is managed.
  final Topic1Model topicData;

  /// Picks a PDF file; replaceable so tests need no real file picker.
  final Future<PickedPdf?> Function() pickFile;

  const Topic1Details(
      {required this.topicData, this.pickFile = pickPdfFile, super.key});

  @override
  State<Topic1Details> createState() => _Topic1DetailsState();
}

class _Topic1DetailsState extends State<Topic1Details> {
  /// `code -> title` per code kind (audio, quiz), so each row can say what
  /// it points at. Absent means "still loading".
  final Map<ContentKind, Map<String, String>> _titles = {};

  /// Code kinds whose lookup failed: their rows say the code couldn't be
  /// checked, rather than that it points at nothing.
  final Set<ContentKind> _checkFailed = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveAll());
  }

  /// Looks up titles for the audio and quiz codes (both at once).
  Future<void> _resolveAll() async {
    await Future.wait([
      for (final ContentKind kind in Topic1Model.codeKinds)
        _resolve(kind, widget.topicData.contentCodes(kind)),
    ]);
  }

  /// Looks up which of [codes] exist and stores their titles.
  Future<void> _resolve(ContentKind kind, List<String> codes) async {
    if (!mounted) return;
    final Topic1ViewModel viewModel =
        Provider.of<Topic1ViewModel>(context, listen: false);
    setState(() => _checkFailed.remove(kind));
    final Map<String, String>? resolved =
        await viewModel.resolveContentTitles(kind, codes);
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

  /// Saves the audio or quiz codes, then re-checks what they point at.
  Future<bool> _saveCodes(
      Topic1ViewModel viewModel, ContentKind kind, List<String> codes) async {
    final bool ok =
        await viewModel.saveContentCodes(widget.topicData, kind, codes);
    if (!ok) return false;
    Helper.showSnackBarMessage(
        msg: "${kind.label} codes saved", isSuccess: true);
    await _resolve(kind, codes);
    return true;
  }

  /// Uploads and saves the PDFs; returns the saved list, or null.
  Future<List<Topic1Pdf>?> _savePdfs(
      Topic1ViewModel viewModel, List<Topic1PdfDraft> drafts) async {
    final bool ok = await viewModel.savePdfs(widget.topicData, drafts);
    if (!ok) return null;
    Helper.showSnackBarMessage(msg: "PDFs saved", isSuccess: true);
    return widget.topicData.pdfList;
  }

  /// Saves the videos.
  Future<bool> _saveVideos(
      Topic1ViewModel viewModel, List<Topic1Video> videos) async {
    final bool ok = await viewModel.saveVideos(widget.topicData, videos);
    if (ok) Helper.showSnackBarMessage(msg: "Videos saved", isSuccess: true);
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    return AdminFormScaffold(
      headerTitle: "New Topics",
      sidebarIndex: topic1ModuleIndex,
      body: (context, width) => FormPageBody(
        width: width,
        children: [
          _pageHeader(),
          const SizedBox(height: AppTokens.gapLg),
          ContentTabs(
              tabs:
                  _tabs(Provider.of<Topic1ViewModel>(context, listen: false))),
          const SizedBox(height: AppTokens.gapLg),
        ],
      ),
    );
  }

  /// PDFs, videos, then audio and quiz codes, one tab each. Each section
  /// keeps its own rows and reports saves through its callback, so nothing
  /// here needs to rebuild when the view model changes.
  List<ContentTab> _tabs(Topic1ViewModel viewModel) {
    final Topic1Model topic = widget.topicData;
    return [
      ContentTab(
        label: contentTabMeta[ContentKind.pdf]!.$1,
        icon: contentTabMeta[ContentKind.pdf]!.$2,
        initialCount: topic.pdfList.length,
        builder: (onState) => Topic1PdfSection(
          key: const ValueKey('topic1_pdfs'),
          initialPdfs: topic.pdfList,
          pickFile: widget.pickFile,
          onSave: (drafts) => _savePdfs(viewModel, drafts),
          onStateChanged: onState,
        ),
      ),
      ContentTab(
        label: contentTabMeta[ContentKind.video]!.$1,
        icon: contentTabMeta[ContentKind.video]!.$2,
        initialCount: topic.videoList.length,
        builder: (onState) => Topic1VideoSection(
          key: const ValueKey('topic1_videos'),
          initialVideos: topic.videoList,
          onSave: (videos) => _saveVideos(viewModel, videos),
          onStateChanged: onState,
        ),
      ),
      for (final ContentKind kind in Topic1Model.codeKinds)
        ContentTab(
          label: contentTabMeta[kind]!.$1,
          icon: contentTabMeta[kind]!.$2,
          initialCount: topic.contentCodes(kind).length,
          builder: (onState) => TopicContentSection(
            key: ValueKey(kind),
            kind: kind,
            initialCodes: topic.contentCodes(kind),
            titles: _titles[kind],
            checkFailed: _checkFailed.contains(kind),
            onRecheck: (codes) => _resolve(kind, codes),
            onSave: (codes) => _saveCodes(viewModel, kind, codes),
            onStateChanged: onState,
          ),
        ),
    ];
  }

  /// The topic card at the top of the page.
  Widget _pageHeader() {
    final Topic1Model data = widget.topicData;
    return TopicHeaderCard(
      name: data.name,
      code: data.code,
      courseName: data.courseName,
      subjectName: data.subjectName,
      unitName: data.unitName,
      // A saved edit (or a delete) closes this page too, so it never shows
      // the old details; the list behind it reloads.
      onEdit: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => EditTopic1(topicData: data)),
      ).ifSaved(() {
        if (mounted) Navigator.pop(context, true);
      }),
      hint: "Upload PDFs and add YouTube links; audio and quizzes attach by "
          "code. Each tab saves on its own.",
    );
  }
}
