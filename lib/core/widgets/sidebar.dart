import 'package:bbarna/banners/screen/banner_list.dart';
import 'package:flutter/material.dart';
import 'package:bbarna/core/widgets/app_header.dart';
import 'package:bbarna/core/widgets/sidebar_widget.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/course/screen/course_list.dart';
import 'package:bbarna/live_class/screen/live_class_list.dart';
import 'package:bbarna/documents/audio/screen/audio_list.dart';
import 'package:bbarna/documents/pdf/screen/pdf_list.dart';
import 'package:bbarna/documents/video/screen/video_list.dart';
import 'package:bbarna/question/screen/question_list.dart';
import 'package:bbarna/quiz/screen/quiz_list.dart';
import 'package:bbarna/student/screen/student_list.dart';
import 'package:bbarna/subject/screen/subject_list.dart';
import 'package:bbarna/teacher/screen/teacher_list.dart';
import 'package:bbarna/topic/screen/topic_list.dart';
import 'package:bbarna/units/screen/unit_list.dart';
import 'package:bbarna/utils/helper.dart';

/// The app shell: a fixed-width navigation rail (collapsible to icons)
/// beside the selected module's list screen. Below
/// [AppTokens.compactBreakpoint] the rail moves into a drawer.
class Sidebar extends StatefulWidget {
  /// Module to open first (index into [moduleList]).
  final int sidebarIndex;
  const Sidebar({required this.sidebarIndex, super.key});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  /// Lets the header's menu button open the drawer.
  final GlobalKey<ScaffoldState> key = GlobalKey();

  /// The module currently shown.
  int selectedIndex = 0;

  /// Whether the rail is reduced to icons.
  bool _collapsed = false;

  /// One list screen per module, index-aligned with [moduleList].
  List<Widget> screenList = [
    const BannerList(),
    const CourseList(),
    const SubjectList(),
    const UnitList(),
    const TopicList(),
    const VideoList(),
    const PDFList(),
    const AudioList(),
    const QuizList(),
    const QuestionList(),
    const StudentList(),
    const TeacherList(),
    const LiveClassList(),
  ];

  @override
  void initState() {
    selectedIndex = widget.sidebarIndex;
    _collapsed = Helper.isSidebarCollapsed();
    super.initState();
  }

  /// Collapses / expands the rail and remembers the choice.
  void _toggleCollapsed() {
    setState(() => _collapsed = !_collapsed);
    // Remembered so the choice survives the pushReplacement that every
    // add/edit screen does on its way back here.
    Helper.setSidebarCollapsed(_collapsed);
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isCompact = width < AppTokens.compactBreakpoint;

    return SafeArea(
      child: Scaffold(
        key: key,
        backgroundColor: AppTokens.canvas,
        body: PopScope(
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            // handle back press
          },
          canPop: false,
          child: Column(
            children: [
              AppHeader(onTapIcon: () => key.currentState?.openDrawer()),
              Expanded(
                child: Row(
                  children: [
                    if (!isCompact)
                      SidebarNav(
                        selectedIndex: selectedIndex,
                        collapsed: _collapsed,
                        onToggleCollapsed: _toggleCollapsed,
                        onSelect: (moduleIndex) =>
                            setState(() => selectedIndex = moduleIndex),
                      ),
                    Expanded(child: screenList[selectedIndex]),
                  ],
                ),
              ),
            ],
          ),
        ),
        drawer: isCompact
            ? Drawer(
                width: AppTokens.railWidth,
                backgroundColor: AppTokens.surface,
                child: ExtraSideBar(
                  sidebarIndex: selectedIndex,
                  isFromLogin: true,
                ),
              )
            : null,
      ),
    );
  }
}

/// Bare logo+nav-list, embedded (not a full page like [Sidebar]) — used as
/// the static side panel and narrow-width [Drawer] content across every
/// add/edit screen, and by [Sidebar]'s own narrow-width drawer above.
///
/// Selecting a module here leaves the current screen for [Sidebar], since
/// those pages have no content area of their own to swap.
class ExtraSideBar extends StatelessWidget {
  /// Module to highlight.
  final int sidebarIndex;

  /// Set when shown right after login.
  final bool isFromLogin;
  const ExtraSideBar(
      {required this.sidebarIndex, this.isFromLogin = false, super.key});

  @override
  Widget build(BuildContext context) {
    return SidebarNav(
      selectedIndex: sidebarIndex,
      onSelect: (moduleIndex) {
        // Not from a drawer: there is no drawer route to unwind first.
        if (!isFromLogin) Navigator.pop(context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => Sidebar(sidebarIndex: moduleIndex)),
        );
      },
    );
  }
}

/// The navigation itself — brand mark, grouped module list, and (when the
/// host offers one) a collapse toggle.
///
/// Shared by [Sidebar] and [ExtraSideBar] so the two always match.
class SidebarNav extends StatelessWidget {
  /// Highlighted module.
  final int selectedIndex;

  /// Called with the tapped module's index.
  final ValueChanged<int> onSelect;

  /// When null the rail sizes itself to whatever box it is given and drops
  /// to icons on its own if that box is narrow — which is what the
  /// `Expanded(child: ExtraSideBar(...))` panels on the add/edit screens
  /// hand it. When non-null the host is driving the width and the collapse
  /// toggle is shown.
  final bool? collapsed;

  /// Collapses / expands the rail (host-driven mode only).
  final VoidCallback? onToggleCollapsed;

  const SidebarNav({
    required this.selectedIndex,
    required this.onSelect,
    this.collapsed,
    this.onToggleCollapsed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bool hostDriven = collapsed != null;

    if (!hostDriven) {
      return LayoutBuilder(builder: (context, constraints) {
        final bool tooNarrowForLabels =
            constraints.maxWidth < AppTokens.railAutoCollapseWidth;
        return _body(isCollapsed: tooNarrowForLabels);
      });
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: collapsed! ? AppTokens.railCollapsedWidth : AppTokens.railWidth,
      child: _body(isCollapsed: collapsed!),
    );
  }

  /// Brand mark and the modules this user may open, grouped.
  Widget _body({required bool isCollapsed}) {
    final List<int> allowed = Helper.allowedModuleIndices();

    return Container(
      decoration: const BoxDecoration(
        color: AppTokens.surface,
        border: Border(right: BorderSide(color: AppTokens.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _brand(isCollapsed),
          const Divider(height: 1, thickness: 1, color: AppTokens.hairline),
          Expanded(child: _modules(allowed, isCollapsed)),
          if (onToggleCollapsed != null) ...[
            const Divider(height: 1, thickness: 1, color: AppTokens.hairline),
            _collapseToggle(isCollapsed),
          ],
        ],
      ),
    );
  }

  /// A 60px brand row rather than the old 200px logo box, which spent a
  /// fifth of the rail's height on a picture and pushed the last modules
  /// below the fold on a laptop.
  Widget _brand(bool isCollapsed) {
    // The logo asset is a white badge, so on a white rail it needs a
    // tinted chip behind it to read as a mark at all.
    final Widget logo = Container(
      height: 34,
      width: 34,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppTokens.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: AppTokens.hairline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusSm - 3),
        child: Image.asset("assets/images/logo.png", fit: BoxFit.contain),
      ),
    );

    return SizedBox(
      height: 60,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 16),
        child: isCollapsed
            ? Center(child: logo)
            : Row(
                children: [
                  logo,
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "B BARNA",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: AppTokens.ink),
                        ),
                        Text(
                          "Admin portal",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: AppTokens.inkFaint),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// One flat list, in [moduleList] order, of the modules this user may
  /// see.
  Widget _modules(List<int> allowed, bool isCollapsed) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.gapSm),
      children: [
        for (final int moduleIndex in allowed)
          SidebarWidget(
            iconData: moduleIconList[moduleIndex],
            itemText: moduleDisplayList[moduleIndex],
            isSelected: moduleIndex == selectedIndex,
            isCollapsed: isCollapsed,
            onTap: () => onSelect(moduleIndex),
          ),
      ],
    );
  }

  /// The « / » button at the bottom of the rail.
  Widget _collapseToggle(bool isCollapsed) {
    return Tooltip(
      message: isCollapsed ? "Expand sidebar" : "Collapse sidebar",
      child: InkWell(
        onTap: onToggleCollapsed,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              if (!isCollapsed) const SizedBox(width: 19),
              Icon(
                isCollapsed
                    ? Icons.keyboard_double_arrow_right
                    : Icons.keyboard_double_arrow_left,
                size: 17,
                color: AppTokens.inkFaint,
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 11),
                const Text("Collapse",
                    style:
                        TextStyle(fontSize: 12.5, color: AppTokens.inkFaint)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
