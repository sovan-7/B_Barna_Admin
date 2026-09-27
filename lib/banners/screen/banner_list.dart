import 'package:bbarna/banners/model/banners_model.dart';
import 'package:bbarna/banners/screen/add_banner.dart';
import 'package:bbarna/banners/viewModel/banners_view_model.dart';
import 'package:bbarna/banners/widgets/banner_card.dart';
import 'package:bbarna/core/widgets/add_widget.dart';
import 'package:bbarna/core/widgets/list_page/list_empty_state.dart';
import 'package:bbarna/core/widgets/list_page/list_error_state.dart';
import 'package:bbarna/core/widgets/list_page/list_page_frame.dart';
import 'package:bbarna/core/widgets/list_page/list_page_header.dart';
import 'package:bbarna/core/widgets/remove_alert.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:bbarna/resources/constant.dart';
import 'package:bbarna/utils/helper.dart';
import 'package:bbarna/utils/navigation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The banner grid (sidebar module).
///
/// The number of columns follows the available width (see [columnsFor]),
/// and the tiles keep a banner's own 16:9 shape.
class BannerList extends StatefulWidget {
  const BannerList({super.key});

  @override
  State<BannerList> createState() => _BannerListState();
}

class _BannerListState extends State<BannerList> {
  /// Tiles stop growing past this; a wider window gets another column.
  static const double _tileMinWidth = 300;

  @override
  void initState() {
    super.initState();
    // Deferred to after the first frame: this screen is mounted from
    // Sidebar's `screenList[selectedIndex]` *during* a build, and loading
    // notifies listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<BannersViewModel>(context, listen: false).getBannerList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BannersViewModel>(
        builder: (context, bannersViewModel, child) {
      return ListPageFrame(
        children: [
          ListPageHeader(
            title: "Banners",
            count: bannersViewModel.bannersList.length,
            subtitle: "Shown in the app's home carousel, in this order.",
            trailing: AddWidget(
              title: "NEW BANNER",
              addCall: () => _openAdd(bannersViewModel),
            ),
          ),
          const SizedBox(height: AppTokens.gapLg),
          Expanded(child: _body(bannersViewModel)),
        ],
      );
    });
  }

  /// Skeleton tiles while loading, the empty state when there are no
  /// banners, otherwise the grid.
  Widget _body(BannersViewModel bannersViewModel) {
    if (bannersViewModel.isLoading) {
      return const _SkeletonGrid(tileMinWidth: _tileMinWidth);
    }
    final String? loadError = bannersViewModel.loadError;
    if (bannersViewModel.bannersList.isEmpty && loadError != null) {
      return ListErrorState(
          title: loadError, onRetry: bannersViewModel.getBannerList);
    }
    if (bannersViewModel.bannersList.isEmpty) {
      return ListEmptyState(
        icon: Icons.image_outlined,
        title: "No banners yet",
        message: "Banners you upload appear on the app's home screen.",
        messageWidth: 320,
        addLabel: "Upload a banner",
        addIcon: Icons.upload_outlined,
        onAdd: () => _openAdd(bannersViewModel),
      );
    }
    return _grid(bannersViewModel);
  }

  /// Opens Add Banner and reloads the grid if a banner was
  /// uploaded.
  void _openAdd(BannersViewModel bannersViewModel) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddBanner()),
    ).ifSaved(() => bannersViewModel.getBannerList());
  }

  /// The banners as a wrap of 16:9 tiles, as many columns as fit.
  Widget _grid(BannersViewModel bannersViewModel) {
    final List<BannersModel> bannersList = bannersViewModel.bannersList;

    return LayoutBuilder(builder: (context, constraints) {
      final int columns = columnsFor(constraints.maxWidth, _tileMinWidth);
      final double tileWidth = columns == 1
          ? constraints.maxWidth
          : (constraints.maxWidth - AppTokens.gapMd * (columns - 1)) / columns;

      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppTokens.gapMd),
        child: Wrap(
          spacing: AppTokens.gapMd,
          runSpacing: AppTokens.gapMd,
          children: [
            for (int i = 0; i < bannersList.length; i++)
              SizedBox(
                width: tileWidth,
                child: BannerCard(
                  key: ValueKey(bannersList[i].docId),
                  banner: bannersList[i],
                  position: i + 1,
                  onDelete: () => _confirmDelete(bannersViewModel, i),
                ),
              ),
          ],
        ),
      );
    });
  }

  /// Captures the doc id up front rather than reading
  /// `bannersList[index]` again inside the async callback — by the time the
  /// user confirms, a refresh may have reordered the list under it.
  void _confirmDelete(BannersViewModel bannersViewModel, int index) {
    final String docId = bannersViewModel.bannersList[index].docId;

    RemoveAlert.showRemoveAlert(
      title: "Banner ${index + 1}",
      description: "Are you sure want to delete ?",
      onPressYes: () async {
        // RemoveAlert never closes itself. It stays open, its confirm button
        // spinning, until the delete is done.
        final bool success = await bannersViewModel.deleteBanner(docId);
        Navigator.pop(navigatorKey.currentContext!);
        if (success) {
          Helper.showInfoMessage(msg: "Banner deleted successfully");
        }
      },
    );
  }
}

/// Columns that fit [width] at [tileMinWidth] apiece, capped so tiles never
/// get so wide that four banners fill a whole monitor.
int columnsFor(double width, double tileMinWidth) =>
    (width / tileMinWidth).floor().clamp(1, 5);

/// Grey 16:9 placeholder tiles (two rows) shown while banners load.
class _SkeletonGrid extends StatelessWidget {
  /// Narrowest a tile may be (decides the column count).
  final double tileMinWidth;
  const _SkeletonGrid({required this.tileMinWidth});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final int columns = columnsFor(constraints.maxWidth, tileMinWidth);
      final double tileWidth = columns == 1
          ? constraints.maxWidth
          : (constraints.maxWidth - AppTokens.gapMd * (columns - 1)) / columns;

      return Wrap(
        spacing: AppTokens.gapMd,
        runSpacing: AppTokens.gapMd,
        children: [
          // Two rows' worth — enough to read as "loading", not so many that
          // the page scrolls before there is anything to scroll.
          for (int i = 0; i < columns * 2; i++)
            SizedBox(
              width: tileWidth,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTokens.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    border: Border.all(color: AppTokens.hairline),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}
