import 'package:bbarna/core/widgets/add_widget.dart';
import 'package:bbarna/core/widgets/paged_list_footer.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/units/model/unit_model.dart';
import 'package:bbarna/units/screen/add_unit.dart';
import 'package:bbarna/units/viewModel/unit_view_model.dart';
import 'package:bbarna/units/widgets/unit_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The unit list.
///
/// Units are paged 50 at a time and the pages *accumulate* — "Next" always
/// appended to one growing list rather than turning a page. So the control
/// is "Load more" now, with an honest "showing N of M" beside it, instead
/// of a Previous/Next pair whose Previous could only chop rows back off the
/// end (and, because it indexed `unitList` with `docList`'s length after
/// mutating it, chopped the wrong ones).
class UnitList extends StatefulWidget {
  const UnitList({super.key});

  @override
  State<UnitList> createState() => _UnitListState();
}

class _UnitListState extends State<UnitList> {
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Put back what was being searched when this list was last left;
    // the view model keeps it across Add/Edit and module switches.
    searchController.text =
        Provider.of<UnitViewModel>(context, listen: false).searchText;
    // Deferred to after the first frame: this screen is mounted from
    // Sidebar's `screenList[selectedIndex]` *during* a build, and the fetch
    // notifies synchronously.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<UnitViewModel>(context, listen: false).refresh();
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
      child: Consumer<UnitViewModel>(builder: (context, unitViewModel, child) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(unitViewModel),
              const SizedBox(height: AppTokens.gapMd),
              _search(unitViewModel),
              const SizedBox(height: AppTokens.gapMd),
              Expanded(child: _body(unitViewModel)),
              if (!unitViewModel.isLoading && unitViewModel.unitList.isNotEmpty)
                _footer(unitViewModel),
            ],
          ),
        );
      }),
    );
  }

  Widget _header(UnitViewModel unitViewModel) {
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
                    child: Text("Units",
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
                    child: Text("${unitViewModel.unitLength}",
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTokens.inkMuted)),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              const Text("Newest first. Each unit sits under one subject.",
                  style: AppTokens.pageSubtitle),
            ],
          ),
        ),
        const SizedBox(width: AppTokens.gapMd),
        AddWidget(
          title: "NEW UNIT",
          addCall: () => _openAdd(unitViewModel),
        ),
      ],
    );
  }

  void _openAdd(UnitViewModel unitViewModel) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddUnit()),
    ).whenComplete(() {
      unitViewModel.refresh();
    });
  }

  /// The hint says "code" on purpose: this search is a server-side prefix
  /// match on `unit_code`, because the collection is paged and most of it
  /// is not in memory to filter. The old box just said "Search".
  Widget _search(UnitViewModel unitViewModel) {
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
                hintText: "Search by unit code",
                hintStyle:
                    TextStyle(fontSize: 13, color: AppTokens.inkFaint),
              ),
              onChanged: (_) {
                unitViewModel.searchUnit(searchText: searchController.text);
                setState(() {});
              },
            ),
          ),
          if (hasText)
            InkWell(
              onTap: () {
                searchController.clear();
                unitViewModel.searchUnit(searchText: "");
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

  Widget _body(UnitViewModel unitViewModel) {
    if (unitViewModel.isLoading) return const _SkeletonList();

    final List<UnitModel> units = unitViewModel.unitList;
    if (units.isEmpty) {
      return _EmptyState(
        isFiltered: searchController.text.trim().isNotEmpty,
        onAdd: () => _openAdd(unitViewModel),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppTokens.gapMd),
      itemCount: units.length,
      itemBuilder: (context, index) => UnitCard(
        key: ValueKey(units[index].id),
        unitData: units[index],
        onChanged: unitViewModel.refresh,
      ),
    );
  }

  Widget _footer(UnitViewModel unitViewModel) {
    return PagedListFooter(
      shown: unitViewModel.unitList.length,
      total: unitViewModel.unitLength,
      isSearching: unitViewModel.isSearching,
      hasMore: unitViewModel.hasMore,
      isLoadingMore: unitViewModel.isLoadingMore,
      pageSize: unitViewModel.limit,
      onLoadMore: unitViewModel.getNextUnitList,
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
                  isFiltered ? Icons.search_off : Icons.layers_outlined,
                  size: 28,
                  color: AppTokens.inkFaint),
            ),
            const SizedBox(height: AppTokens.gapMd),
            Text(isFiltered ? "No matches" : "No units yet",
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
                    // query is a prefix match on the code, so "mech" finds
                    // MECH-01 but never a unit merely named Mechanics.
                    ? "No unit code starts with that. Search matches the code, not the name."
                    : "Units sit under a subject, and topics hang off them.",
                textAlign: TextAlign.center,
                style: AppTokens.pageSubtitle,
              ),
            ),
            if (!isFiltered) ...[
              const SizedBox(height: AppTokens.gapLg),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 16),
                label: const Text("Add a unit"),
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
