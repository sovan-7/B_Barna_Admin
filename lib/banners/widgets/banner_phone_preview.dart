import 'package:bbarna/banners/model/banners_model.dart';
import 'package:bbarna/banners/widgets/banner_card.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

/// A phone outline showing the student app's home screen with [banners]
/// in its carousel, [selected] on screen — so an admin sees a banner the
/// way students will before anything else.
class BannerPhonePreview extends StatelessWidget {
  /// Every banner, in carousel order.
  final List<BannersModel> banners;

  /// The one showing (an index into [banners]).
  final int selected;

  const BannerPhonePreview(
      {required this.banners, required this.selected, super.key});

  /// Width of the phone outline.
  static const double width = 210;

  @override
  Widget build(BuildContext context) {
    final int shown =
        selected.clamp(0, banners.isEmpty ? 0 : banners.length - 1);
    return Container(
      key: const Key('banner_phone_preview'),
      width: width,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTokens.inkFaint.withValues(alpha: .6)),
        boxShadow: AppTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 54,
              height: 5,
              decoration: BoxDecoration(
                color: AppTokens.hairline,
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text("Student app · home",
              style: TextStyle(fontSize: 11, color: AppTokens.inkFaint)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: banners.isEmpty
                  ? Container(color: AppTokens.surfaceMuted)
                  : bannerImage(banners[shown].bannerImage),
            ),
          ),
          const SizedBox(height: 8),
          // The carousel's dots, the current one stretched.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < banners.length && i < 8; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: i == shown ? 14 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: i == shown ? AppTokens.accent : AppTokens.hairline,
                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Stand-ins for the rest of the home screen.
          for (int row = 0; row < 2; row++) ...[
            if (row > 0) const SizedBox(height: 6),
            Row(
              children: [
                for (int col = 0; col < 2; col++) ...[
                  if (col > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTokens.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            banners.isEmpty
                ? "No banners to show"
                : "Slide ${shown + 1} of ${banners.length}",
            key: const Key('banner_preview_caption'),
            style: const TextStyle(fontSize: 11.5, color: AppTokens.inkMuted),
          ),
        ],
      ),
    );
  }
}
