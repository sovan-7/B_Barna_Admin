import 'package:bbarna/banners/screen/banner_list.dart';
import 'package:bbarna/book_orders/screen/book_order_list.dart';
import 'package:bbarna/books/screen/book_list.dart';
import 'package:bbarna/notifications/screen/notification_list.dart';
import 'package:flutter/material.dart';
import 'package:bbarna/core/widgets/app_header.dart';
import 'package:bbarna/core/widgets/brand_mark.dart';
import 'package:bbarna/core/widgets/list_page/list_empty_state.dart';
import 'package:bbarna/core/widgets/sidebar_widget.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/course/screen/course_list.dart';
import 'package:bbarna/live_class/screen/live_class_list.dart';
import 'package:bbarna/documents/audio/screen/audio_list.dart';
import 'package:bbarna/documents/pdf/screen/pdf_list.dart';
import 'package:bbarna/documents/video/screen/video_list.dart';
import 'package:bbarna/question/screen/question_list.dart';
import 'package:bbarna/question1/screen/question1_list.dart';
import 'package:bbarna/quiz/screen/quiz_list.dart';
import 'package:bbarna/student/screen/student_list.dart';
import 'package:bbarna/subject/screen/subject_list.dart';
import 'package:bbarna/teacher/screen/teacher_list.dart';
import 'package:bbarna/transactions/screen/transaction_list.dart';
import 'package:bbarna/topic/screen/topic_list.dart';
import 'package:bbarna/topic1/screen/topic1_list.dart';
import 'package:bbarna/units/screen/unit_list.dart';
import 'package:bbarna/utils/helper.dart';

/// The app shell: the navy navigation rail (collapsible to icons) beside
/// the selected module's list screen, under the slim [AppHeader]. Below
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

  /// The module currently shown; null when this user may open none.
  int? selectedIndex;

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
    const BookList(),
    const BookOrderList(),
    const NotificationList(),
    const TransactionList(),
    const Topic1List(),
    const Question1List(),
  ];

  @override
  void initState() {
    // The requested module only if this user may open it; otherwise the
    // first one the rail lists, if any.
    final List<int> allowed = Helper.allowedModuleIndices();
    final List<int> inRailOrder = railOrder(allowed);
    selectedIndex = allowed.contains(widget.sidebarIndex)
        ? widget.sidebarIndex
        : (inRailOrder.isEmpty ? null : inRailOrder.first);
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
    final double width = MediaQuery.sizeOf(context).width;
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
          child: Row(
            children: [
              if (!isCompact)
                SidebarNav(
                  selectedIndex: selectedIndex ?? -1,
                  collapsed: _collapsed,
                  onToggleCollapsed: _toggleCollapsed,
                  onSelect: (moduleIndex) =>
                      setState(() => selectedIndex = moduleIndex),
                ),
              Expanded(
                child: Column(
                  children: [
                    AppHeader(
                      onTapIcon: () => key.currentState?.openDrawer(),
                      moduleIndex: selectedIndex,
                    ),
                    Expanded(
                      child: selectedIndex == null
                          ? const ListEmptyState(
                              icon: Icons.lock_outline,
                              title: "No modules assigned",
                              message:
                                  "Ask an admin to give your account access "
                                  "to at least one module.",
                            )
                          : screenList[selectedIndex!],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        drawer: isCompact
            ? Drawer(
                width: AppTokens.railWidth,
                backgroundColor: AppTokens.brandNavy,
                child: ExtraSideBar(
                  sidebarIndex: selectedIndex ?? -1,
                  isFromLogin: true,
                ),
              )
            : null,
      ),
    );
  }
}

/// [allowed] module positions in the order the rail lists them: group by
/// group, as [moduleGroups] orders them.
List<int> railOrder(List<int> allowed) {
  final Set<int> allowedSet = allowed.toSet();
  return [
    for (final ModuleGroup group in moduleGroups)
      for (final int moduleIndex in group.modules)
        if (allowedSet.contains(moduleIndex)) moduleIndex,
  ];
}

/// Logo + nav list for pages that are not [Sidebar] itself: the rail beside
/// every add/edit screen ([inline]) and the narrow-width [Drawer] content
/// everywhere, [Sidebar]'s own drawer included.
///
/// Selecting a module here leaves the current screen for [Sidebar], since
/// those pages have no content area of their own to swap.
class ExtraSideBar extends StatefulWidget {
  /// Module to highlight.
  final int sidebarIndex;

  /// Set when shown right after login.
  final bool isFromLogin;

  /// Shown as the rail beside a page (with the collapse toggle and the same
  /// remembered width as [Sidebar]) rather than filling whatever box it is
  /// given, as it does in a drawer.
  final bool inline;

  const ExtraSideBar(
      {required this.sidebarIndex,
      this.isFromLogin = false,
      this.inline = false,
      super.key});

  @override
  State<ExtraSideBar> createState() => _ExtraSideBarState();
}

class _ExtraSideBarState extends State<ExtraSideBar> {
  /// Whether the inline rail is reduced to icons.
  bool _collapsed = Helper.isSidebarCollapsed();

  @override
  Widget build(BuildContext context) {
    return SidebarNav(
      selectedIndex: widget.sidebarIndex,
      collapsed: widget.inline ? _collapsed : null,
      onToggleCollapsed: widget.inline
          ? () {
              setState(() => _collapsed = !_collapsed);
              Helper.setSidebarCollapsed(_collapsed);
            }
          : null,
      onSelect: (moduleIndex) {
        // In a drawer this closes the drawer; inline it leaves the add/edit
        // page, so the replacement below lands on the Sidebar under it.
        if (!widget.isFromLogin) Navigator.pop(context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => Sidebar(sidebarIndex: moduleIndex)),
        );
      },
    );
  }
}

/// The navigation itself — brand mark, the modules this user may open under
/// their group headings, and (when the host offers one) a collapse toggle.
///
/// Shared by [Sidebar] and [ExtraSideBar] so the two always match.
class SidebarNav extends StatelessWidget {
  /// Highlighted module.
  final int selectedIndex;

  /// Called with the tapped module's index.
  final ValueChanged<int> onSelect;

  /// When null the rail sizes itself to whatever box it is given and drops
  /// to icons on its own if that box is narrow — which is what a drawer
  /// hands it. When non-null the host is driving the width and the collapse
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

  /// Brand mark and the grouped modules this user may open.
  Widget _body({required bool isCollapsed}) {
    final List<int> allowed = Helper.allowedModuleIndices();

    return Container(
      color: AppTokens.brandNavy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _brand(isCollapsed),
          Expanded(child: _modules(allowed, isCollapsed)),
          if (onToggleCollapsed != null) ...[
            const Divider(
                height: 1, thickness: 1, color: AppTokens.brandNavyRaised),
            _collapseToggle(isCollapsed),
          ],
        ],
      ),
    );
  }

  /// A compact brand row the same height as the header beside it.
  Widget _brand(bool isCollapsed) {
    return SizedBox(
      height: AppTokens.headerHeight,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 16),
        child: isCollapsed
            ? const Center(child: BrandMark())
            : const Row(
                children: [
                  BrandMark(),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "B_BARNA",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: Colors.white),
                        ),
                        Text(
                          "Admin portal",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: AppTokens.onNavyMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// The modules this user may see, under their [moduleGroups] headings.
  /// Groups with nothing to show are left out; collapsed, the headings
  /// become thin dividers.
  Widget _modules(List<int> allowed, bool isCollapsed) {
    final Set<int> allowedSet = allowed.toSet();
    final List<Widget> children = [];

    for (final ModuleGroup group in moduleGroups) {
      final List<int> shown = [
        for (final int moduleIndex in group.modules)
          if (allowedSet.contains(moduleIndex)) moduleIndex,
      ];
      if (shown.isEmpty) continue;

      children.add(isCollapsed
          ? Padding(
              padding:
                  EdgeInsets.fromLTRB(18, children.isEmpty ? 4 : 10, 18, 6),
              child: const Divider(
                  height: 1, thickness: 1, color: AppTokens.brandNavyRaised),
            )
          : Padding(
              padding:
                  EdgeInsets.fromLTRB(20, children.isEmpty ? 6 : 14, 12, 4),
              child: Text(
                group.label,
                key: ValueKey('nav_group_${group.label}'),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: AppTokens.onNavyMuted),
              ),
            ));

      for (final int moduleIndex in shown) {
        children.add(SidebarWidget(
          iconData: moduleIconList[moduleIndex],
          itemText: moduleDisplayList[moduleIndex],
          isSelected: moduleIndex == selectedIndex,
          isCollapsed: isCollapsed,
          onTap: () => onSelect(moduleIndex),
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: AppTokens.gapSm),
      children: children,
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
              if (!isCollapsed) const SizedBox(width: 22),
              Icon(
                isCollapsed
                    ? Icons.keyboard_double_arrow_right
                    : Icons.keyboard_double_arrow_left,
                size: 17,
                color: AppTokens.onNavyMuted,
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 11),
                const Text("Collapse",
                    style: TextStyle(
                        fontSize: 12.5, color: AppTokens.onNavyMuted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
