import 'package:bbarna/core/widgets/add_widget.dart';
import 'package:bbarna/core/widgets/paged_list_footer.dart';
import 'package:bbarna/documents/pdf/model/pdf_model.dart';
import 'package:bbarna/documents/pdf/screen/add_pdf.dart';
import 'package:bbarna/documents/pdf/viewModel/pdf_view_model.dart';
import 'package:bbarna/documents/pdf/widgets/pdf_card.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The PDF list.
class PDFList extends StatefulWidget {
  const PDFList({super.key});

  @override
  State<PDFList> createState() => _PDFListState();
}

class _PDFListState extends State<PDFList> {
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Put back what was being searched when this list was last left;
    // the view model keeps it across Add/Edit and module switches.
    searchController.text =
        Provider.of<PdfViewModel>(context, listen: false).searchText;
    // Deferred to after the first frame: this screen is mounted from
    // Sidebar's `screenList[selectedIndex]` *during* a build, and the fetch
    // notifies synchronously.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<PdfViewModel>(context, listen: false).refresh();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTokens.canvas,
      child:
          Consumer<PdfViewModel>(builder: (context, pdfViewModel, child) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(pdfViewModel),
              const SizedBox(height: AppTokens.gapMd),
              _search(pdfViewModel),
              const SizedBox(height: AppTokens.gapMd),
              Expanded(child: _body(pdfViewModel)),
              if (!pdfViewModel.isLoading &&
                  pdfViewModel.pdfList.isNotEmpty)
                PagedListFooter(
                  shown: pdfViewModel.pdfList.length,
                  total: pdfViewModel.pdfListLength,
                  isSearching: pdfViewModel.isSearching,
                  hasMore: pdfViewModel.hasMore,
                  isLoadingMore: pdfViewModel.isLoadingMore,
                  pageSize: pdfViewModel.limit,
                  onLoadMore: pdfViewModel.getNextPdfList,
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _header(PdfViewModel pdfViewModel) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Flexible(
                    child: Text("PDFs",
                        overflow: TextOverflow.ellipsis,
                        style: AppTokens.pageTitle),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTokens.surface,
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusPill),
                      border: Border.all(color: AppTokens.hairline),
                    ),
                    child: Text("${pdfViewModel.pdfListLength}",
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTokens.inkMuted)),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              const Text("Newest first. Free PDFs open without a purchase.",
                  style: AppTokens.pageSubtitle),
            ],
          ),
        ),
        const SizedBox(width: AppTokens.gapMd),
        AddWidget(
          title: "NEW PDF",
          addCall: () => _openAdd(pdfViewModel),
        ),
      ],
    );
  }

  void _openAdd(PdfViewModel pdfViewModel) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddPdf()),
    ).whenComplete(() {
      pdfViewModel.refresh();
    });
  }

  /// The hint says "code" on purpose: this search is a server-side prefix
  /// match on `video_code`, because the collection is paged and most of it
  /// is not in memory to filter. The old box just said "Search".
  Widget _search(PdfViewModel pdfViewModel) {
    final bool hasText = searchController.text.isNotEmpty;

    return Container(
      height: 40,
      constraints: const BoxConstraints(maxWidth: 380),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppTokens.hairline),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 17, color: AppTokens.inkFaint),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: searchController,
              style: const TextStyle(fontSize: 13, color: AppTokens.ink),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: "Search by PDF code",
                hintStyle:
                    TextStyle(fontSize: 13, color: AppTokens.inkFaint),
              ),
              onChanged: (_) {
                pdfViewModel.searchPdf(searchText: searchController.text);
                setState(() {});
              },
            ),
          ),
          if (hasText)
            InkWell(
              onTap: () {
                searchController.clear();
                pdfViewModel.searchPdf(searchText: "");
                setState(() {});
              },
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child:
                    Icon(Icons.close, size: 16, color: AppTokens.inkMuted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(PdfViewModel pdfViewModel) {
    if (pdfViewModel.isLoading) return const _SkeletonList();

    final List<PdfModel> videos = pdfViewModel.pdfList;
    if (videos.isEmpty) {
      return _EmptyState(
        isFiltered: searchController.text.trim().isNotEmpty,
        onAdd: () => _openAdd(pdfViewModel),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppTokens.gapMd),
      itemCount: videos.length,
      itemBuilder: (context, index) => PdfCard(
        key: ValueKey(videos[index].docId),
        pdfData: videos[index],
        onChanged: pdfViewModel.refresh,
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        height: 88,
        margin: const EdgeInsets.only(bottom: AppTokens.gapSm),
        decoration: BoxDecoration(
          color: AppTokens.surfaceMuted,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(color: AppTokens.hairline),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isFiltered;
  final VoidCallback onAdd;
  const _EmptyState({required this.isFiltered, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: const BoxDecoration(
                  color: AppTokens.surfaceMuted, shape: BoxShape.circle),
              child: Icon(
                  isFiltered ? Icons.search_off : Icons.picture_as_pdf_outlined,
                  size: 28,
                  color: AppTokens.inkFaint),
            ),
            const SizedBox(height: AppTokens.gapMd),
            Text(isFiltered ? "No matches" : "No PDFs yet",
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.ink)),
            const SizedBox(height: 5),
            SizedBox(
              width: 340,
              child: Text(
                isFiltered
                    // Saying which field was searched matters: the query is
                    // a prefix match on the code, so "intro" finds INTRO-01
                    // but never a video merely titled Introduction.
                    ? "No PDF code starts with that. Search matches the code, not the title."
                    : "Upload a PDF and students can read it inside the app.",
                textAlign: TextAlign.center,
                style: AppTokens.pageSubtitle,
              ),
            ),
            if (!isFiltered) ...[
              const SizedBox(height: AppTokens.gapLg),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 16),
                label: const Text("Add a PDF"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTokens.ink,
                  side: const BorderSide(color: AppTokens.hairline),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusMd)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
