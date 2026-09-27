import 'package:bbarna/core/widgets/list_page/list_empty_state.dart';
import 'package:bbarna/core/widgets/list_page/list_error_state.dart';
import 'package:bbarna/core/widgets/list_page/list_page_frame.dart';
import 'package:bbarna/core/widgets/list_page/list_page_header.dart';
import 'package:bbarna/core/widgets/list_page/list_search_field.dart';
import 'package:bbarna/core/widgets/list_page/list_skeleton.dart';
import 'package:bbarna/core/widgets/paged_list_footer.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/student/model/student_model.dart';
import 'package:bbarna/student/repo/student_repo.dart';
import 'package:bbarna/student/viewModel/student_view_model.dart';
import 'package:bbarna/student/widgets/student_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The student list (sidebar module).
///
/// Paged 300 at a time, sortable by name or last sign-in, with a local
/// search over the pages already loaded. Students cannot be added here —
/// they sign up in the app.
class StudentList extends StatefulWidget {
  const StudentList({super.key});

  @override
  State<StudentList> createState() => _StudentListState();
}

class _StudentListState extends State<StudentList> {
  /// Text in the search box.
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
      Provider.of<StudentViewModel>(context, listen: false)
          .fetchFirstStudentList();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentViewModel>(
        builder: (context, studentViewModel, child) {
      return ListPageFrame(
        children: [
          _header(studentViewModel),
          const SizedBox(height: AppTokens.gapMd),
          ListSearchField(
            controller: searchController,
            hintText: "Search by name, phone or email",
            onChanged: (text) => _search(studentViewModel, text),
            onCleared: () => _search(studentViewModel, ""),
          ),
          // Only in "Last active" order, when some students are missing.
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
      );
    });
  }

  /// Filters the list (the view model rebuilds the page).
  void _search(StudentViewModel studentViewModel, String text) {
    // The view model notifies straight away, which rebuilds this page
    // (clear button and empty-state wording included) — no setState needed.
    studentViewModel.searchStudent(searchText: text);
  }

  /// Title, total count, a subtitle that names the current order, and the
  /// sort toggle on the right (students are not added from here).
  Widget _header(StudentViewModel studentViewModel) {
    return ListPageHeader(
      title: "Students",
      count: studentViewModel.studentListLength,
      subtitle: studentViewModel.sort == StudentSort.lastActive
          ? "Most recently active first. Search filters the "
              "students already loaded."
          : "By name. Search filters the students already loaded.",
      trailing: _sortToggle(studentViewModel),
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

  /// One segment of the sort toggle; tapping it re-sorts (and reloads).
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

  /// Skeleton while loading, empty state when there are no rows, otherwise
  /// the student cards.
  Widget _body(StudentViewModel studentViewModel) {
    if (studentViewModel.isLoading) {
      return const ListSkeleton(rowHeight: 72);
    }

    final List<Student> students = studentViewModel.studentList;
    // A failed load: say so, with Retry, rather than "No … yet".
    final String? loadError = studentViewModel.loadError;
    if (students.isEmpty && loadError != null) {
      return ListErrorState(
          title: loadError, onRetry: studentViewModel.fetchFirstStudentList);
    }
    if (students.isEmpty) {
      // No add button: students sign up in the app, not here.
      return ListEmptyState(
        isFiltered: searchController.text.trim().isNotEmpty,
        icon: Icons.people_outline,
        title: "No students yet",
        message: "Students appear here once they sign up in the app.",
        // Search only covers the students already loaded; point at loading
        // more only when there are more to load.
        filteredMessage: studentViewModel.copyStudentList.length <
                studentViewModel.reachableTotal
            ? "No loaded student matches that name, phone or email. Clear the search and load more to widen it."
            : "No student matches that name, phone or email.",
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
