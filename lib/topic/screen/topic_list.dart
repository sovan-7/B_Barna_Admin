import 'package:bbarna/core/widgets/add_widget.dart';
import 'package:bbarna/core/widgets/paged_list_footer.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/topic/model/topic_model.dart';
import 'package:bbarna/topic/screen/add_topic.dart';
import 'package:bbarna/topic/viewModel/topic_view_model.dart';
import 'package:bbarna/topic/widgets/topic_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The topic list.
///
/// Topics are paged 50 at a time and the pages *accumulate* — "Next" always
/// appended to one growing list rather than turning a page. So the control
/// is "Load more" now, with an honest "showing N of M" beside it, instead
/// of a Previous/Next pair whose Previous could only chop rows back off the
/// end (and, because it indexed `topicList` with `docList`'s length after
/// mutating it, chopped the wrong ones).
class TopicList extends StatefulWidget {
  const TopicList({super.key});

  @override
  State<TopicList> createState() => _TopicListState();
}

class _TopicListState extends State<TopicList> {
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Put back what was being searched when this list was last left;
    // the view model keeps it across Add/Edit and module switches.
    searchController.text =
        Provider.of<TopicViewModel>(context, listen: false).searchText;
    // Deferred to after the first frame: this screen is mounted from
    // Sidebar's `screenList[selectedIndex]` *during* a build, and the fetch
    // notifies synchronously.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<TopicViewModel>(context, listen: false).refresh();
      // The add/edit form needs the course list for its course picker.
      final CourseViewModel courseViewModel =
          Provider.of<CourseViewModel>(context, listen: false);
      if (courseViewModel.allCourses.isEmpty) courseViewModel.getCourseList();
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
          Consumer<TopicViewModel>(builder: (context, topicViewModel, child) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(topicViewModel),
              const SizedBox(height: AppTokens.gapMd),
              _search(topicViewModel),
              const SizedBox(height: AppTokens.gapMd),
              Expanded(child: _body(topicViewModel)),
              if (!topicViewModel.isLoading &&
                  topicViewModel.topicList.isNotEmpty)
                _footer(topicViewModel),
            ],
          ),
        );
      }),
    );
  }

  Widget _header(TopicViewModel topicViewModel) {
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
                    child: Text("Topics",
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
                    child: Text("${topicViewModel.topicLength}",
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTokens.inkMuted)),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              const Text(
                  "Newest first. Videos, audio, PDFs and quizzes hang off a topic.",
                  style: AppTokens.pageSubtitle),
            ],
          ),
        ),
        const SizedBox(width: AppTokens.gapMd),
        AddWidget(
          title: "NEW TOPIC",
          addCall: () => _openAdd(topicViewModel),
        ),
      ],
    );
  }

  void _openAdd(TopicViewModel topicViewModel) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddTopic()),
    ).whenComplete(() {
      topicViewModel.refresh();
    });
  }

  /// The hint says "code" on purpose: this search is a server-side prefix
  /// match on `topic_code`, because the collection is paged and most of it
  /// is not in memory to filter. The old box just said "Search".
  Widget _search(TopicViewModel topicViewModel) {
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
                hintText: "Search by topic code",
                hintStyle:
                    TextStyle(fontSize: 13, color: AppTokens.inkFaint),
              ),
              onChanged: (_) {
                topicViewModel.searchTopic(searchText: searchController.text);
                setState(() {});
              },
            ),
          ),
          if (hasText)
            InkWell(
              onTap: () {
                searchController.clear();
                topicViewModel.searchTopic(searchText: "");
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

  Widget _body(TopicViewModel topicViewModel) {
    if (topicViewModel.isLoading) return const _SkeletonList();

    final List<TopicModel> topics = topicViewModel.topicList;
    if (topics.isEmpty) {
      return _EmptyState(
        isFiltered: searchController.text.trim().isNotEmpty,
        onAdd: () => _openAdd(topicViewModel),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppTokens.gapMd),
      itemCount: topics.length,
      itemBuilder: (context, index) => TopicCard(
        key: ValueKey(topics[index].docId),
        topicData: topics[index],
        onChanged: topicViewModel.refresh,
      ),
    );
  }

  Widget _footer(TopicViewModel topicViewModel) {
    return PagedListFooter(
      shown: topicViewModel.topicList.length,
      total: topicViewModel.topicLength,
      isSearching: topicViewModel.isSearching,
      hasMore: topicViewModel.hasMore,
      isLoadingMore: topicViewModel.isLoadingMore,
      pageSize: topicViewModel.limit,
      onLoadMore: topicViewModel.getNextTopicList,
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
        height: 82,
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
                  isFiltered ? Icons.search_off : Icons.topic_outlined,
                  size: 28,
                  color: AppTokens.inkFaint),
            ),
            const SizedBox(height: AppTokens.gapMd),
            Text(isFiltered ? "No matches" : "No topics yet",
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.ink)),
            const SizedBox(height: 5),
            SizedBox(
              width: 340,
              child: Text(
                isFiltered
                    // Saying which field was searched matters here: the
                    // query is a prefix match on the code, so "newt" finds
                    // NEWT-01 but never a topic merely named Newton's Laws.
                    ? "No topic code starts with that. Search matches the code, not the name."
                    : "Topics sit under a unit, and content hangs off them.",
                textAlign: TextAlign.center,
                style: AppTokens.pageSubtitle,
              ),
            ),
            if (!isFiltered) ...[
              const SizedBox(height: AppTokens.gapLg),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 16),
                label: const Text("Add a topic"),
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
