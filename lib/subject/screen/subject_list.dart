import 'package:bbarna/core/widgets/add_widget.dart';
import 'package:bbarna/core/widgets/list_page/list_empty_state.dart';
import 'package:bbarna/core/widgets/list_page/list_page_frame.dart';
import 'package:bbarna/core/widgets/list_page/list_page_header.dart';
import 'package:bbarna/core/widgets/list_page/list_search_field.dart';
import 'package:bbarna/core/widgets/list_page/list_skeleton.dart';
import 'package:bbarna/course/viewModel/course_view_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/subject/model/subject_model.dart';
import 'package:bbarna/subject/screen/add_subject.dart';
import 'package:bbarna/subject/viewModel/subject_view_model.dart';
import 'package:bbarna/subject/widgets/subject_card.dart';
import 'package:bbarna/utils/navigation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The subject list (sidebar module).
///
/// Every subject is loaded at once and the search filters them locally by
/// subject name, code or course name (no paging, so no footer).
class SubjectList extends StatefulWidget {
  const SubjectList({super.key});

  @override
  State<SubjectList> createState() => _SubjectListState();
}

class _SubjectListState extends State<SubjectList> {
  /// Text in the search box.
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Put back what was being searched when this list was last left; the
    // view model keeps it across Add/Edit and module switches.
    searchController.text =
        Provider.of<SubjectViewModel>(context, listen: false).searchText;
    // Deferred to after the first frame: this screen is mounted from
    // Sidebar's `screenList[selectedIndex]` *during* a build, and loading
    // notifies listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<SubjectViewModel>(context, listen: false).getSubjectList();
      // The add/edit form needs the course list for its course picker.
      final CourseViewModel courseViewModel =
          Provider.of<CourseViewModel>(context, listen: false);
      if (courseViewModel.allCourses.isEmpty) {
        courseViewModel.getCourseList();
      }
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SubjectViewModel>(
        builder: (context, subjectViewModel, child) {
      return ListPageFrame(
        children: [
          ListPageHeader(
            title: "Subjects",
            count: subjectViewModel.subjectList.length,
            subtitle: "Newest first. Each subject belongs to one course.",
            trailing: AddWidget(
              title: "NEW SUBJECT",
              addCall: () => _openAdd(subjectViewModel),
            ),
          ),
          const SizedBox(height: AppTokens.gapMd),
          ListSearchField(
            controller: searchController,
            hintText: "Search by subject, code or course",
            onChanged: (text) => _search(subjectViewModel, text),
            onCleared: () => _search(subjectViewModel, ""),
          ),
          const SizedBox(height: AppTokens.gapMd),
          Expanded(child: _body(subjectViewModel)),
        ],
      );
    });
  }

  /// Filters the list and rebuilds (for the clear button / empty wording).
  void _search(SubjectViewModel subjectViewModel, String text) {
    subjectViewModel.searchSubject(searchText: text);
    setState(() {});
  }

  /// Opens Add Subject and reloads the list if something was
  /// saved.
  void _openAdd(SubjectViewModel subjectViewModel) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddSubject()),
    ).ifSaved(() {
      subjectViewModel.getSubjectList();
    });
  }

  /// Skeleton while loading, empty state when there are no rows, otherwise
  /// the subject cards.
  Widget _body(SubjectViewModel subjectViewModel) {
    if (subjectViewModel.isLoading) {
      return const ListSkeleton(rowHeight: 78, rowCount: 5);
    }

    final List<SubjectModel> subjects = subjectViewModel.subjectList;
    if (subjects.isEmpty) {
      return ListEmptyState(
        isFiltered: searchController.text.trim().isNotEmpty,
        icon: Icons.library_books_outlined,
        title: "No subjects yet",
        message: "Subjects sit under a course, and units hang off them.",
        filteredMessage: "No subject matches that name, code or course.",
        addLabel: "Add a subject",
        onAdd: () => _openAdd(subjectViewModel),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppTokens.gapMd),
      itemCount: subjects.length,
      itemBuilder: (context, index) => SubjectCard(
        key: ValueKey(subjects[index].docId),
        subjectData: subjects[index],
        onChanged: subjectViewModel.getSubjectList,
      ),
    );
  }
}
