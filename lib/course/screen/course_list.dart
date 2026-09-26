import 'package:bbarna/core/widgets/add_widget.dart';
import 'package:bbarna/course/model/course_model.dart';
import 'package:bbarna/course/screen/add_course.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/course/widgets/course_card.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The course list.
class CourseList extends StatefulWidget {
  const CourseList({super.key});

  @override
  State<CourseList> createState() => _CourseListState();
}

class _CourseListState extends State<CourseList> {
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Put back what was being searched when this list was last left;
    // the view model keeps it across Add/Edit and module switches.
    searchController.text =
        Provider.of<CourseViewModel>(context, listen: false).searchText;
    // Deferred to after the first frame: this screen is mounted from
    // Sidebar's `screenList[selectedIndex]` *during* a build, and the fetch
    // notifies synchronously.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<CourseViewModel>(context, listen: false).getCourseList();
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
          Consumer<CourseViewModel>(builder: (context, courseViewModel, child) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(courseViewModel),
              const SizedBox(height: AppTokens.gapMd),
              _search(courseViewModel),
              const SizedBox(height: AppTokens.gapMd),
              Expanded(child: _body(courseViewModel)),
            ],
          ),
        );
      }),
    );
  }

  Widget _header(CourseViewModel courseViewModel) {
    final int count = courseViewModel.courseList.length;

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
                    child: Text("Courses",
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
                    child: Text("$count",
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTokens.inkMuted)),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              const Text("Newest first. Locked courses are hidden from students.",
                  style: AppTokens.pageSubtitle),
            ],
          ),
        ),
        const SizedBox(width: AppTokens.gapMd),
        AddWidget(
          title: "NEW COURSE",
          addCall: () => _openAdd(courseViewModel),
        ),
      ],
    );
  }

  void _openAdd(CourseViewModel courseViewModel) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddCourse()),
    ).whenComplete(() {
      courseViewModel.getCourseList();
    });
  }

  Widget _search(CourseViewModel courseViewModel) {
    final bool hasText = searchController.text.isNotEmpty;

    return Container(
      height: 40,
      constraints: const BoxConstraints(maxWidth: 360),
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
                hintText: "Search by name or code",
                hintStyle:
                    TextStyle(fontSize: 13, color: AppTokens.inkFaint),
              ),
              onChanged: (_) {
                courseViewModel.searchCourse(
                    searchText: searchController.text);
                setState(() {});
              },
            ),
          ),
          if (hasText)
            InkWell(
              onTap: () {
                searchController.clear();
                courseViewModel.searchCourse(
                    searchText: searchController.text);
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

  Widget _body(CourseViewModel courseViewModel) {
    if (courseViewModel.isLoading) return const _SkeletonList();

    final List<CourseModel> courses = courseViewModel.courseList;
    if (courses.isEmpty) {
      return _EmptyState(
        isFiltered: searchController.text.trim().isNotEmpty,
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

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) => Container(
        height: 74,
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
                  isFiltered ? Icons.search_off : Icons.menu_book_outlined,
                  size: 28,
                  color: AppTokens.inkFaint),
            ),
            const SizedBox(height: AppTokens.gapMd),
            Text(isFiltered ? "No matches" : "No courses yet",
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.ink)),
            const SizedBox(height: 5),
            SizedBox(
              width: 320,
              child: Text(
                isFiltered
                    ? "No course matches that name or code."
                    : "Courses are the top level of the catalogue — subjects and units hang off them.",
                textAlign: TextAlign.center,
                style: AppTokens.pageSubtitle,
              ),
            ),
            if (!isFiltered) ...[
              const SizedBox(height: AppTokens.gapLg),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 16),
                label: const Text("Add a course"),
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
