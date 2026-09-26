import 'package:bbarna/core/widgets/paged_list_footer.dart';
import 'package:bbarna/student/model/student_model.dart';
import 'package:bbarna/student/repo/student_repo.dart';
import 'package:bbarna/student/viewModel/student_viewmodel.dart';
import 'package:bbarna/student/widgets/student_card.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The student list.
class StudentList extends StatefulWidget {
  const StudentList({super.key});

  @override
  State<StudentList> createState() => _StudentListState();
}

class _StudentListState extends State<StudentList> {
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Put back what was being searched when this list was last left;
    // the view model keeps it across Add/Edit and module switches.
    searchController.text =
        Provider.of<StudentViewModel>(context, listen: false).searchText;
    // Deferred to after the first frame: this screen is mounted from
    // Sidebar's `screenList[selectedIndex]` *during* a build, and the fetch
    // notifies synchronously.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<StudentViewModel>(context, listen: false).fetchFirstStudentList();
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
          Consumer<StudentViewModel>(builder: (context, studentViewModel, child) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(studentViewModel),
              const SizedBox(height: AppTokens.gapMd),
              _search(studentViewModel),
              if (studentViewModel.studentsNeverSignedIn > 0) ...[
                const SizedBox(height: AppTokens.gapSm),
                _neverSignedInNote(studentViewModel),
              ],
              const SizedBox(height: AppTokens.gapMd),
              Expanded(child: _body(studentViewModel)),
              if (!studentViewModel.isLoading &&
                  studentViewModel.studentList.isNotEmpty)
                PagedListFooter(
                  shown: studentViewModel.studentList.length,
                  isSearching: studentViewModel.isSearching,
                  hasMore: studentViewModel.hasMore,
                  isLoadingMore: studentViewModel.isLoadingMore,
                  total: studentViewModel.reachableTotal,
                  pageSize: studentViewModel.limit,
                  onLoadMore: studentViewModel.fetchNextStudentList,
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _header(StudentViewModel studentViewModel) {
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
                    child: Text("Students",
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
                    child: Text("${studentViewModel.studentListLength}",
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTokens.inkMuted)),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                  studentViewModel.sort == StudentSort.lastActive
                      ? "Most recently active first. Search filters the "
                          "students already loaded."
                      : "By name. Search filters the students already loaded.",
                  style: AppTokens.pageSubtitle),
            ],
          ),
        ),
        const SizedBox(width: AppTokens.gapMd),
        _sortToggle(studentViewModel),
      ],
    );
  }

  /// Name or last active. Two segments rather than a dropdown: there are
  /// only ever two, and which one is on should be readable without opening
  /// anything.
  Widget _sortToggle(StudentViewModel studentViewModel) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: AppTokens.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final StudentSort option in StudentSort.values)
            _sortSegment(studentViewModel, option),
        ],
      ),
    );
  }

  Widget _sortSegment(StudentViewModel studentViewModel, StudentSort option) {
    final bool selected = studentViewModel.sort == option;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      child: InkWell(
        key: Key('student_sort_${option.name}'),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        onTap: selected ? null : () => studentViewModel.setSort(option),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppTokens.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            border: Border.all(
                color: selected ? AppTokens.hairline : Colors.transparent),
            boxShadow: selected ? AppTokens.cardShadow : null,
          ),
          child: Text(
            option.label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? AppTokens.ink : AppTokens.inkMuted,
            ),
          ),
        ),
      ),
    );
  }

  /// Sorting on `login_time` makes Firestore omit every student that has
  /// never signed in — they are absent from the query, not merely last.
  /// Saying so is the difference between a shorter list and a list that has
  /// quietly lost people.
  Widget _neverSignedInNote(StudentViewModel studentViewModel) {
    final int count = studentViewModel.studentsNeverSignedIn;

    return Container(
      key: const Key('student_never_signed_in_note'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: AppTokens.hairline),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 14, color: AppTokens.inkFaint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              count == 1
                  ? "1 student has never signed in and is not listed here. "
                      "Sort by name to see them."
                  : "$count students have never signed in and are not listed "
                      "here. Sort by name to see them.",
              style: const TextStyle(
                  fontSize: 12, height: 1.35, color: AppTokens.inkMuted),
            ),
          ),
        ],
      ),
    );
  }

  /// The hint says "code" on purpose: this search is a server-side prefix
  /// match on `video_code`, because the collection is paged and most of it
  /// is not in memory to filter. The old box just said "Search".
  Widget _search(StudentViewModel studentViewModel) {
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
                hintText: "Search by name, phone or email",
                hintStyle:
                    TextStyle(fontSize: 13, color: AppTokens.inkFaint),
              ),
              onChanged: (_) {
                studentViewModel.searchStudent(searchText: searchController.text);
                setState(() {});
              },
            ),
          ),
          if (hasText)
            InkWell(
              onTap: () {
                searchController.clear();
                studentViewModel.searchStudent(searchText: "");
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

  Widget _body(StudentViewModel studentViewModel) {
    if (studentViewModel.isLoading) return const _SkeletonList();

    final List<Student> students = studentViewModel.studentList;
    if (students.isEmpty) {
      return _EmptyState(
        isFiltered: searchController.text.trim().isNotEmpty,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppTokens.gapMd),
      itemCount: students.length,
      itemBuilder: (context, index) => StudentCard(
        key: ValueKey(students[index].studentId),
        student: students[index],
        onChanged: studentViewModel.fetchFirstStudentList,
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
        height: 72,
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
  const _EmptyState({required this.isFiltered});

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
                  isFiltered ? Icons.search_off : Icons.people_outline,
                  size: 28,
                  color: AppTokens.inkFaint),
            ),
            const SizedBox(height: AppTokens.gapMd),
            Text(isFiltered ? "No matches" : "No students yet",
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
                    ? "No loaded student matches that name, phone or email. Load more to widen the search."
                    : "Students appear here once they sign up in the app.",
                textAlign: TextAlign.center,
                style: AppTokens.pageSubtitle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
