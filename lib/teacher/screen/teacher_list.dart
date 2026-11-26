import 'package:bbarna/core/widgets/add_widget.dart';
import 'package:bbarna/core/widgets/list_page/list_empty_state.dart';
import 'package:bbarna/core/widgets/list_page/list_error_state.dart';
import 'package:bbarna/core/widgets/list_page/list_page_frame.dart';
import 'package:bbarna/core/widgets/list_page/list_page_header.dart';
import 'package:bbarna/core/widgets/list_page/list_search_field.dart';
import 'package:bbarna/core/widgets/list_page/list_skeleton.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/teacher/model/teacher_model.dart';
import 'package:bbarna/teacher/screen/add_teacher.dart';
import 'package:bbarna/teacher/viewModel/teacher_view_model.dart';
import 'package:bbarna/teacher/widgets/teacher_card.dart';
import 'package:bbarna/teacher/widgets/teacher_list_controls.dart';
import 'package:bbarna/teacher/widgets/teacher_roster_table.dart';
import 'package:bbarna/utils/navigation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The teacher list (sidebar module).
///
/// Every teacher is loaded at once; the search (name or username) and the
/// role filter narrow them locally (no paging, so no footer). With room for
/// it the teachers are a table ([TeacherRosterTable]); narrower, each is a
/// [TeacherCard].
class TeacherList extends StatefulWidget {
  const TeacherList({super.key});

  @override
  State<TeacherList> createState() => _TeacherListState();
}

class _TeacherListState extends State<TeacherList> {
  /// Narrowest content width that still gets the table rather than cards.
  static const double _tableMinWidth = 720;

  /// Narrowest content width with the role filter beside the search box.
  static const double _filterBesideSearchMinWidth = 600;

  /// Text in the search box.
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Put back what was being searched when this list was last left; the
    // view model keeps it across Add/Edit and module switches.
    searchController.text =
        Provider.of<TeacherViewModel>(context, listen: false).searchText;
    // Deferred to after the first frame: this screen is mounted from
    // Sidebar's `screenList[selectedIndex]` *during* a build, and loading
    // notifies listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<TeacherViewModel>(context, listen: false).getTeacherList();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TeacherViewModel>(
        builder: (context, teacherViewModel, child) {
      return ListPageFrame(
        children: [
          ListPageHeader(
            title: "Teachers",
            count: teacherViewModel.teacherList.length,
            subtitle: "Role and module access at a glance.",
            trailing: AddWidget(
              title: "NEW TEACHER",
              addCall: () => _openAdd(teacherViewModel),
            ),
          ),
          const SizedBox(height: AppTokens.gapMd),
          TeacherStatsStrip(
            total: teacherViewModel.totalCount,
            admins: teacherViewModel.adminCount,
            subadmins: teacherViewModel.subadminCount,
          ),
          const SizedBox(height: AppTokens.gapMd),
          _searchRow(teacherViewModel),
          const SizedBox(height: AppTokens.gapMd),
          Expanded(child: _body(teacherViewModel)),
        ],
      );
    });
  }

  /// The search box and the role filter: side by side when there is room,
  /// otherwise the filter goes under the search box.
  Widget _searchRow(TeacherViewModel teacherViewModel) {
    final Widget search = ListSearchField(
      controller: searchController,
      hintText: "Search by name or username",
      onChanged: (text) => _search(teacherViewModel, text),
      onCleared: () => _search(teacherViewModel, ""),
    );
    final Widget filter = TeacherRoleFilter(
      selected: teacherViewModel.roleFilter,
      onChanged: teacherViewModel.setRoleFilter,
    );

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < _filterBesideSearchMinWidth) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            search,
            const SizedBox(height: AppTokens.gapSm),
            filter,
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: search),
          const SizedBox(width: AppTokens.gapSm),
          filter,
        ],
      );
    });
  }

  /// Filters the list (the view model rebuilds the page).
  void _search(TeacherViewModel teacherViewModel, String text) {
    // The view model notifies straight away, which rebuilds this page
    // (clear button and empty-state wording included) — no setState needed.
    teacherViewModel.searchTeacher(searchText: text);
  }

  /// Opens Add Teacher and reloads the list if something was
  /// saved.
  void _openAdd(TeacherViewModel teacherViewModel) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddTeacher()),
    ).ifSaved(() {
      teacherViewModel.getTeacherList();
    });
  }

  /// Skeleton while loading, empty state when there are no rows, otherwise
  /// the teachers as a table (wide) or cards (narrow).
  Widget _body(TeacherViewModel teacherViewModel) {
    return LayoutBuilder(builder: (context, constraints) {
      final bool asTable = constraints.maxWidth >= _tableMinWidth;

      if (teacherViewModel.isLoading) {
        return ListSkeleton(rowHeight: asTable ? 52 : 96);
      }

      final List<TeacherModel> teachers = teacherViewModel.teacherList;
      // A failed load: say so, with Retry, rather than "No … yet".
      final String? loadError = teacherViewModel.loadError;
      if (teachers.isEmpty && loadError != null) {
        return ListErrorState(
            title: loadError, onRetry: teacherViewModel.getTeacherList);
      }
      if (teachers.isEmpty) {
        return ListEmptyState(
          isFiltered: searchController.text.trim().isNotEmpty ||
              teacherViewModel.roleFilter != null,
          icon: Icons.people_alt_outlined,
          title: "No teachers yet",
          message:
              "Teachers sign in to this panel with the modules you grant them.",
          filteredMessage: "No teacher matches that search or role.",
          addLabel: "Add a teacher",
          onAdd: () => _openAdd(teacherViewModel),
        );
      }

      if (asTable) {
        return TeacherRosterTable(
          teachers: teachers,
          onChanged: teacherViewModel.getTeacherList,
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: AppTokens.gapMd),
        itemCount: teachers.length,
        itemBuilder: (context, index) => TeacherCard(
          key: ValueKey(teachers[index].username),
          teacherData: teachers[index],
          onChanged: teacherViewModel.getTeacherList,
        ),
      );
    });
  }
}
