import 'package:bbarna/banners/model/banners_model.dart';
import 'package:bbarna/resources/app_tokens.dart';
import 'package:flutter/material.dart';

/// One banner tile in the banner grid: the image (16:9, cropped to fit —
/// the same way the app's home carousel shows it), its position badge,
/// and a delete button on hover.
class BannerCard extends StatefulWidget {
  /// The item shown in this row.
  final BannersModel banner;

  /// 1-based position, shown as a corner badge — the grid order is the
  /// order the app shows them in, and there is otherwise nothing on screen
  /// that says so.
  final int position;
  final VoidCallback onDelete;

  const BannerCard({
    required this.banner,
    required this.position,
    required this.onDelete,
    super.key,
  });

  @override
  State<BannerCard> createState() => _BannerCardState();
}

class _BannerCardState extends State<BannerCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool canHover = MediaQuery.of(context).size.width > 900;
    final bool showActions = _hovered || !canHover;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: AppTokens.surface,
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(
              color: _hovered
                  ? AppTokens.inkFaint.withValues(alpha: .5)
                  : AppTokens.hairline),
          boxShadow: AppTokens.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _image(),
                _badge(),
                _deleteButton(showActions),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// `Image.network` rather than a `DecorationImage`, because only the
  /// widget form gives a loading and an error builder — and a banner whose
  /// upload failed is exactly the row most likely to be in this grid.
  Widget _image() {
    final String url = widget.banner.bannerImage;
    if (url.trim().isEmpty) return _unavailable("No image uploaded");

    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: AppTokens.surfaceMuted,
          alignment: Alignment.center,
          child: SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppTokens.inkFaint,
              value: progress.expectedTotalBytes == null
                  ? null
                  : progress.cumulativeBytesLoaded /
                      progress.expectedTotalBytes!,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stack) =>
          _unavailable("Image unavailable"),
    );
  }

  /// Grey placeholder shown instead of a missing / broken image.
  Widget _unavailable(String message) {
    return Container(
      color: AppTokens.surfaceMuted,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined,
              size: 26, color: AppTokens.inkFaint),
          const SizedBox(height: 6),
          Text(message,
              style:
                  const TextStyle(fontSize: 11.5, color: AppTokens.inkFaint)),
        ],
      ),
    );
  }

  /// The banner's position number in the carousel.
  Widget _badge() {
    return Positioned(
      left: 8,
      top: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          // Dark chip, not a bare number: it has to stay legible over both
          // a white banner and a black one.
          color: Colors.black.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        ),
        child: Text(
          "${widget.position}",
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }

  /// Round delete button in the corner; shown on hover.
  Widget _deleteButton(bool visible) {
    return Positioned(
      right: 8,
      top: 8,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 140),
        opacity: visible ? 1 : 0,
        child: IgnorePointer(
          ignoring: !visible,
          child: Tooltip(
            message: "Delete banner",
            child: Material(
              color: Colors.black.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              child: InkWell(
                onTap: widget.onDelete,
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                child: const Padding(
                  padding: EdgeInsets.all(7),
                  child:
                      Icon(Icons.delete_outline, size: 17, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
