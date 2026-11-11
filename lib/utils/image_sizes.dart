/// Longest side, in pixels, that pictures are stored at.
class ImageSizes {
  const ImageSizes._();

  /// Course / subject / unit / teacher pictures (shown as thumbnails).
  static const int thumbnail = 800;

  /// Home-carousel banners (shown full width).
  static const int banner = 1920;

  /// Push-notification pictures (Firebase drops images over 1 MB).
  static const int notification = 1024;

  /// Pictures posted to a subject's group (notices and posters: big enough
  /// for their small print to stay readable when zoomed on a phone).
  static const int groupPost = 1600;
}
