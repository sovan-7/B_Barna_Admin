import 'package:bbarna/core/widgets/add_widget.dart';
import 'package:bbarna/live_class/model/live_class_model.dart';
import 'package:bbarna/live_class/screen/add_live_class.dart';
import 'package:bbarna/live_class/viewModel/live_class_view_model.dart';
import 'package:bbarna/live_class/widgets/live_class_card.dart';
import 'package:bbarna/live_class/widgets/live_class_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Class list with Upcoming / Live / Past tabs. Buckets are computed from
/// each class's start/end window at render time (see
/// [LiveClassModel.statusAt]) — nothing status-related is stored.
///
/// Laid out as a responsive card grid rather than a single column: this is
/// an admin panel that mostly runs full-screen on a desktop, where a
/// one-column list wastes two thirds of the window and pushes the fourth
/// class below the fold.
class LiveClassList extends StatefulWidget {
  const LiveClassList({super.key});

  @override
  State<LiveClassList> createState() => _LiveClassListState();
}

class _LiveClassListState extends State<LiveClassList> {
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Put back what was being searched when this list was last left;
    // the view model keeps it across Add/Edit and module switches.
    searchController.text =
        Provider.of<LiveClassViewModel>(context, listen: false).searchText;
    // Deferred to after the first frame: this screen is mounted from
    // Sidebar's `screenList[selectedIndex]` *during* a build, and
    // getLiveClassList flips `isLoading` + notifies synchronously — calling
    // it straight from initState would mark the Consumer dirty mid-build
    // ("setState() called during build").
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<LiveClassViewModel>(context, listen: false)
          .getLiveClassList();
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
      color: LiveClassTheme.canvas,
      child: Consumer<LiveClassViewModel>(
          builder: (context, liveClassViewModel, child) {
        final List<LiveClassModel> visible =
            liveClassViewModel.classesFor(liveClassViewModel.selectedStatus);

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(liveClassViewModel),
              const SizedBox(height: LiveClassTheme.gapLg),
              if (liveClassViewModel.classesNeedingAppSync.isNotEmpty) ...[
                _appSyncBanner(liveClassViewModel),
                const SizedBox(height: LiveClassTheme.gapMd),
              ],
              _toolbar(liveClassViewModel),
              const SizedBox(height: LiveClassTheme.gapMd),
              Expanded(
                child: liveClassViewModel.isLoading
                    ? const _SkeletonGrid()
                    : visible.isEmpty
                        ? _EmptyState(
                            status: liveClassViewModel.selectedStatus,
                            isFiltered: searchController.text.trim().isNotEmpty,
                            onSchedule: () => _openAdd(liveClassViewModel),
                          )
                        : _grid(visible, liveClassViewModel),
              ),
            ],
          ),
        );
      }),
    );
  }

  /// Says which classes the student app cannot see, and fixes them.
  ///
  /// Classes saved before this panel started writing the app's field names
  /// reach the app with `startTime: 0`, which files them under Past no
  /// matter when they are scheduled — so a class reads Upcoming here and
  /// Past there at the same moment. Nothing on either screen said why, and
  /// the only tell was that the class was in the wrong list on a device the
  /// admin was not holding.
  Widget _appSyncBanner(LiveClassViewModel liveClassViewModel) {
    final int count = liveClassViewModel.classesNeedingAppSync.length;
    final bool busy = liveClassViewModel.isSyncingForApp;

    return Container(
      key: const Key('live_class_app_sync_banner'),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFB54708).withValues(alpha: .06),
        borderRadius: BorderRadius.circular(LiveClassTheme.radiusMd),
        border:
            Border.all(color: const Color(0xFFB54708).withValues(alpha: .28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sync_problem_outlined,
              size: 17, color: Color(0xFFB54708)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 1
                      ? "1 class is not showing correctly in the app"
                      : "$count classes are not showing correctly in the app",
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: LiveClassTheme.ink),
                ),
                const SizedBox(height: 2),
                const Text(
                  "They were saved before the app's schedule format was "
                  "settled, so students see them under Past whenever they "
                  "are scheduled. Updating rewrites them — set a Subject on "
                  "each afterwards, as older classes have none.",
                  style: TextStyle(
                      fontSize: 12, height: 1.4, color: LiveClassTheme.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: LiveClassTheme.gapMd),
          ElevatedButton(
            key: const Key('live_class_app_sync_button'),
            onPressed:
                busy ? null : () => liveClassViewModel.syncClassesForApp(),
            style: ElevatedButton.styleFrom(
              backgroundColor: LiveClassTheme.ink,
              disabledBackgroundColor:
                  LiveClassTheme.ink.withValues(alpha: .55),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(LiveClassTheme.radiusSm)),
            ),
            child: busy
                ? const SizedBox(
                    height: 15,
                    width: 15,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text("Update them",
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ---- Header ---------------------------------------------------------

  Widget _header(LiveClassViewModel liveClassViewModel) {
    final int total = liveClassViewModel.liveClassList.length;

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
                    child: Text(
                      "Live Classes",
                      overflow: TextOverflow.ellipsis,
                      style: LiveClassTheme.pageTitle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: LiveClassTheme.surface,
                      borderRadius:
                          BorderRadius.circular(LiveClassTheme.radiusPill),
                      border: Border.all(color: LiveClassTheme.hairline),
                    ),
                    child: Text(
                      "$total",
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: LiveClassTheme.inkMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              const Text(
                "Scheduled, running and finished classes.",
                style: LiveClassTheme.pageSubtitle,
              ),
            ],
          ),
        ),
        const SizedBox(width: LiveClassTheme.gapMd),
        AddWidget(
          title: "NEW CLASS",
          addCall: () => _openAdd(liveClassViewModel),
        ),
      ],
    );
  }

  void _openAdd(LiveClassViewModel liveClassViewModel) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddLiveClass()),
    ).whenComplete(() => liveClassViewModel.getLiveClassList());
  }

  // ---- Toolbar --------------------------------------------------------

  /// Tabs and search share a row on desktop and stack below ~760px, so the
  /// segmented control never squeezes the search field into a stub.
  Widget _toolbar(LiveClassViewModel liveClassViewModel) {
    return LayoutBuilder(builder: (context, constraints) {
      final Widget tabs = _tabs(liveClassViewModel);
      final Widget search = _search(liveClassViewModel);

      if (constraints.maxWidth < 760) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Compact segments, and a scroll as the last resort: three tabs
            // plus their counts stop fitting somewhere under ~330px.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _tabs(liveClassViewModel, compact: true),
            ),
            const SizedBox(height: LiveClassTheme.gapSm),
            search,
          ],
        );
      }
      return Row(
        children: [
          tabs,
          const Spacer(),
          SizedBox(width: 300, child: search),
        ],
      );
    });
  }

  /// One connected segmented control instead of three loose pills — the
  /// three buckets are a single choice, and the shared container says so.
  Widget _tabs(LiveClassViewModel liveClassViewModel, {bool compact = false}) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: LiveClassTheme.surface,
        borderRadius: BorderRadius.circular(LiveClassTheme.radiusMd),
        border: Border.all(color: LiveClassTheme.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final LiveClassStatus status in LiveClassStatus.values)
            _tab(liveClassViewModel, status, compact),
        ],
      ),
    );
  }

  Widget _tab(LiveClassViewModel liveClassViewModel, LiveClassStatus status,
      bool compact) {
    final bool isSelected = liveClassViewModel.selectedStatus == status;
    final Color accent = LiveClassTheme.accentFor(status);
    final int count = liveClassViewModel.countFor(status);

    return InkWell(
      key: Key('live_class_tab_${status.name}'),
      borderRadius: BorderRadius.circular(LiveClassTheme.radiusSm + 1),
      onTap: () => liveClassViewModel.selectStatus(status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 11 : 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(LiveClassTheme.radiusSm + 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) ...[
              Icon(
                LiveClassTheme.iconFor(status),
                size: 14,
                color: isSelected ? Colors.white : LiveClassTheme.inkFaint,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              status.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : LiveClassTheme.inkMuted,
              ),
            ),
            const SizedBox(width: 6),
            // The count rides inside the segment as its own chip rather
            // than as "(3)" glued to the label — it stays legible when the
            // segment is filled.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: .25)
                    : LiveClassTheme.surfaceMuted,
                borderRadius:
                    BorderRadius.circular(LiveClassTheme.radiusPill),
              ),
              child: Text(
                "$count",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : LiveClassTheme.inkFaint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _search(LiveClassViewModel liveClassViewModel) {
    final bool hasText = searchController.text.isNotEmpty;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: LiveClassTheme.surface,
        borderRadius: BorderRadius.circular(LiveClassTheme.radiusMd),
        border: Border.all(color: LiveClassTheme.hairline),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 17, color: LiveClassTheme.inkFaint),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: searchController,
              style: const TextStyle(fontSize: 13, color: LiveClassTheme.ink),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: "Search by class or teacher",
                hintStyle:
                    TextStyle(fontSize: 13, color: LiveClassTheme.inkFaint),
              ),
              onChanged: (_) {
                liveClassViewModel.searchLiveClass(
                    searchText: searchController.text);
                setState(() {});
              },
            ),
          ),
          if (hasText)
            InkWell(
              onTap: () {
                searchController.clear();
                liveClassViewModel.searchLiveClass(
                    searchText: searchController.text);
                setState(() {});
              },
              borderRadius: BorderRadius.circular(LiveClassTheme.radiusPill),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close,
                    size: 16, color: LiveClassTheme.inkMuted),
              ),
            ),
        ],
      ),
    );
  }

  // ---- Grid -----------------------------------------------------------

  Widget _grid(
      List<LiveClassModel> visible, LiveClassViewModel liveClassViewModel) {
    return LayoutBuilder(builder: (context, constraints) {
      final int columns = _columnsFor(constraints.maxWidth);
      final double itemWidth = columns == 1
          ? constraints.maxWidth
          : (constraints.maxWidth - LiveClassTheme.gapMd * (columns - 1)) /
              columns;

      // Laid out a row at a time rather than as one flat Wrap. Wrap sizes
      // every child to its own content, so a class with a description stood
      // visibly taller than the one beside it and the row ended ragged.
      // IntrinsicHeight + stretch gives each row one height, set by its
      // tallest card.
      final List<List<LiveClassModel>> rows = <List<LiveClassModel>>[];
      for (int i = 0; i < visible.length; i += columns) {
        final int end = i + columns;
        rows.add(visible.sublist(i, end > visible.length ? visible.length : end));
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: LiveClassTheme.gapMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int r = 0; r < rows.length; r++) ...[
              if (r > 0) const SizedBox(height: LiveClassTheme.gapMd),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int c = 0; c < rows[r].length; c++) ...[
                      if (c > 0) const SizedBox(width: LiveClassTheme.gapMd),
                      SizedBox(
                        width: itemWidth,
                        child: LiveClassCard(
                          key: ValueKey(rows[r][c].docId),
                          liveClassData: rows[r][c],
                          onChanged: () =>
                              liveClassViewModel.getLiveClassList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  static int _columnsFor(double width) =>
      (width / LiveClassTheme.cardMinWidth).floor().clamp(1, 4);
}

/// Placeholder cards while the first fetch is in flight. They occupy the
/// same footprint as the real cards, so the grid doesn't jump when the data
/// lands — which a centred spinner cannot do.
class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final int columns =
          _LiveClassListState._columnsFor(constraints.maxWidth);
      final double itemWidth = columns == 1
          ? constraints.maxWidth
          : (constraints.maxWidth - LiveClassTheme.gapMd * (columns - 1)) /
              columns;

      return Wrap(
        spacing: LiveClassTheme.gapMd,
        runSpacing: LiveClassTheme.gapMd,
        children: [
          for (int i = 0; i < columns * 2; i++)
            SizedBox(width: itemWidth, child: const _SkeletonCard()),
        ],
      );
    });
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  Widget _bar(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: LiveClassTheme.hairline,
          borderRadius: BorderRadius.circular(LiveClassTheme.radiusSm),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: LiveClassTheme.surface,
        borderRadius: BorderRadius.circular(LiveClassTheme.radiusLg),
        border: Border.all(color: LiveClassTheme.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bar(66, 18),
          const SizedBox(height: 12),
          _bar(double.infinity, 13),
          const SizedBox(height: 8),
          _bar(180, 13),
          const SizedBox(height: 16),
          Row(children: [_bar(110, 22), const SizedBox(width: 8), _bar(64, 22)]),
        ],
      ),
    );
  }
}

/// Per-tab empty state. "No past classes" and "nothing matched your search"
/// are different problems, and only one of them is fixed by scheduling a
/// class — so only that one offers the button.
class _EmptyState extends StatelessWidget {
  final LiveClassStatus status;
  final bool isFiltered;
  final VoidCallback onSchedule;

  const _EmptyState(
      {required this.status,
      required this.isFiltered,
      required this.onSchedule});

  @override
  Widget build(BuildContext context) {
    final Color accent = LiveClassTheme.accentFor(status);
    final bool offerCta = !isFiltered && status != LiveClassStatus.past;

    final String title;
    final String subtitle;
    if (isFiltered) {
      title = "No matches";
      subtitle = "No ${status.label.toLowerCase()} class matches that search.";
    } else {
      switch (status) {
        case LiveClassStatus.upcoming:
          title = "Nothing scheduled yet";
          subtitle = "Classes you schedule for a future date show up here.";
        case LiveClassStatus.live:
          title = "No class is running";
          subtitle = "A class appears here between its start and end time.";
        case LiveClassStatus.past:
          title = "No finished classes";
          subtitle = "Classes move here once their end time passes.";
      }
    }

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                color: LiveClassTheme.tintFor(status),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFiltered ? Icons.search_off : LiveClassTheme.iconFor(status),
                size: 28,
                color: accent,
              ),
            ),
            const SizedBox(height: LiveClassTheme.gapMd),
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: LiveClassTheme.ink)),
            const SizedBox(height: 5),
            SizedBox(
              width: 300,
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: LiveClassTheme.pageSubtitle,
              ),
            ),
            if (offerCta) ...[
              const SizedBox(height: LiveClassTheme.gapLg),
              OutlinedButton.icon(
                onPressed: onSchedule,
                icon: const Icon(Icons.calendar_month_outlined, size: 16),
                label: const Text("Schedule a class"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: LiveClassTheme.ink,
                  side: const BorderSide(color: LiveClassTheme.hairline),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(LiveClassTheme.radiusMd)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
