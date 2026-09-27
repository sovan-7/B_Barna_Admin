import 'package:bbarna/core/widgets/add_widget.dart';
import 'package:bbarna/core/widgets/list_page/list_empty_state.dart';
import 'package:bbarna/core/widgets/list_page/list_page_frame.dart';
import 'package:bbarna/core/widgets/list_page/list_page_header.dart';
import 'package:bbarna/core/widgets/list_page/list_search_field.dart';
import 'package:bbarna/core/widgets/list_page/list_skeleton.dart';
import 'package:bbarna/course/model/course_model.dart';
import 'package:bbarna/course/screen/add_course.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/course/widgets/course_card.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/utils/navigation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The course list (sidebar module).
///
/// Every course is loaded at once and the search filters them locally by
/// name or code (no paging, so no footer).
class CourseList extends StatefulWidget {
  const CourseList({super.key});

  @override
  State<CourseList> createState() => _CourseListState();
}

class _CourseListState extends State<CourseList> {
  /// Text in the search box.
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final CourseViewModel courseViewModel =
        Provider.of<CourseViewModel>(context, listen: false);
    // Put back what was being searched when this list was last left; the
    // view model keeps it across Add/Edit and module switches.
    searchController.text = courseViewModel.searchText;
    // Deferred to after the first frame: this screen is mounted from
    // Sidebar's `screenList[selectedIndex]` *during* a build, and loading
    // notifies listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      courseViewModel.getCourseList();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CourseViewModel>(
        builder: (context, courseViewModel, child) {
      return ListPageFrame(
        children: [
          ListPageHeader(
            title: "Courses",
            count: courseViewModel.courseList.length,
            subtitle: "Newest first. Locked courses are hidden from students.",
            trailing: AddWidget(
              title: "NEW COURSE",
              addCall: () => _openAdd(courseViewModel),
            ),
          ),
          const SizedBox(height: AppTokens.gapMd),
          ListSearchField(
            controller: searchController,
            hintText: "Search by name or code",
            maxWidth: 360,
            onChanged: (text) => _search(courseViewModel, text),
            onCleared: () => _search(courseViewModel, ""),
          ),
          const SizedBox(height: AppTokens.gapMd),
          Expanded(child: _body(courseViewModel)),
        ],
      );
    });
  }

  /// Filters the list and rebuilds (for the clear button / empty wording).
  void _search(CourseViewModel courseViewModel, String text) {
    courseViewModel.searchCourse(searchText: text);
    setState(() {});
  }

  /// Opens Add Course and reloads the list if something was
  /// saved.
  void _openAdd(CourseViewModel courseViewModel) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddCourse()),
    ).ifSaved(() {
      courseViewModel.getCourseList();
    });
  }

  /// Skeleton while loading, empty state when there are no rows, otherwise
  /// the course cards.
  Widget _body(CourseViewModel courseViewModel) {
    if (courseViewModel.isLoading) {
      return const ListSkeleton(rowHeight: 74, rowCount: 5);
    }

    final List<CourseModel> courses = courseViewModel.courseList;
    if (courses.isEmpty) {
      return ListEmptyState(
        isFiltered: searchController.text.trim().isNotEmpty,
        icon: Icons.menu_book_outlined,
        title: "No courses yet",
        message:
            "Courses are the top level of the catalogue — subjects and units hang off them.",
        filteredMessage: "No course matches that name or code.",
        messageWidth: 320,
        addLabel: "Add a course",
        onAdd: () => _openAdd(courseViewModel),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppTokens.gapMd),
      itemCount: courses.length,
      itemBuilder: (context, index) => CourseCard(
        key: ValueKey(courses[index].docId),
        courseData: courses[index],
        onChanged: courseViewModel.getCourseList,
      ),
    );
  }
}
