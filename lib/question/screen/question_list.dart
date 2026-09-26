import 'package:bbarna/core/widgets/add_widget.dart';
import 'package:bbarna/core/widgets/paged_list_footer.dart';
import 'package:bbarna/question/model/question.dart';
import 'package:bbarna/question/screen/add_question.dart';
import 'package:bbarna/question/question_viewmodel/question_viewmodel.dart';
import 'package:bbarna/question/widgets/question_card.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The question list.
class QuestionList extends StatefulWidget {
  const QuestionList({super.key});

  @override
  State<QuestionList> createState() => _QuestionListState();
}

class _QuestionListState extends State<QuestionList> {
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Put back what was being searched when this list was last left;
    // the view model keeps it across Add/Edit and module switches.
    searchController.text =
        Provider.of<QuestionViewModel>(context, listen: false).searchText;
    // Deferred to after the first frame: this screen is mounted from
    // Sidebar's `screenList[selectedIndex]` *during* a build, and the fetch
    // notifies synchronously.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<QuestionViewModel>(context, listen: false).refresh();
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
          Consumer<QuestionViewModel>(builder: (context, questionViewModel, child) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(questionViewModel),
              const SizedBox(height: AppTokens.gapMd),
              _search(questionViewModel),
              const SizedBox(height: AppTokens.gapMd),
              Expanded(child: _body(questionViewModel)),
              if (!questionViewModel.isLoading &&
                  questionViewModel.questionList.isNotEmpty)
                PagedListFooter(
                  shown: questionViewModel.questionList.length,
                  total: questionViewModel.questionListLength,
                  isSearching: questionViewModel.isSearching,
                  hasMore: questionViewModel.hasMore,
                  isLoadingMore: questionViewModel.isLoadingMore,
                  pageSize: questionViewModel.limit,
                  onLoadMore: questionViewModel.fetchNextQuestionList,
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _header(QuestionViewModel questionViewModel) {
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
                    child: Text("Questions",
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
                    child: Text("${questionViewModel.questionListLength}",
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTokens.inkMuted)),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              const Text("Newest first. Questions are attached to quizzes by their code.",
                  style: AppTokens.pageSubtitle),
            ],
          ),
        ),
        const SizedBox(width: AppTokens.gapMd),
        AddWidget(
          title: "NEW QUESTION",
          addCall: () => _openAdd(questionViewModel),
        ),
      ],
    );
  }

  void _openAdd(QuestionViewModel questionViewModel) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddQuestion()),
    ).whenComplete(() {
      questionViewModel.refresh();
    });
  }

  /// The hint says "code" on purpose: this search is a server-side prefix
  /// match on `video_code`, because the collection is paged and most of it
  /// is not in memory to filter. The old box just said "Search".
  Widget _search(QuestionViewModel questionViewModel) {
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
                hintText: "Search by question code",
                hintStyle:
                    TextStyle(fontSize: 13, color: AppTokens.inkFaint),
              ),
              onChanged: (_) {
                questionViewModel.searchQuestion(searchText: searchController.text);
                setState(() {});
              },
            ),
          ),
          if (hasText)
            InkWell(
              onTap: () {
                searchController.clear();
                questionViewModel.searchQuestion(searchText: "");
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

  Widget _body(QuestionViewModel questionViewModel) {
    if (questionViewModel.isLoading) return const _SkeletonList();

    final List<Question> videos = questionViewModel.questionList;
    if (videos.isEmpty) {
      return _EmptyState(
        isFiltered: searchController.text.trim().isNotEmpty,
        onAdd: () => _openAdd(questionViewModel),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppTokens.gapMd),
      itemCount: videos.length,
      itemBuilder: (context, index) => QuestionCard(
        key: ValueKey(videos[index].docId),
        questionData: videos[index],
        onChanged: questionViewModel.refresh,
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
        height: 76,
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
                  isFiltered ? Icons.search_off : Icons.help_outline,
                  size: 28,
                  color: AppTokens.inkFaint),
            ),
            const SizedBox(height: AppTokens.gapMd),
            Text(isFiltered ? "No matches" : "No questions yet",
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
                    ? "No question code starts with that. Search matches the code, not the text."
                    : "Questions live here on their own, and quizzes pull them in by code.",
                textAlign: TextAlign.center,
                style: AppTokens.pageSubtitle,
              ),
            ),
            if (!isFiltered) ...[
              const SizedBox(height: AppTokens.gapLg),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 16),
                label: const Text("Add a question"),
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
