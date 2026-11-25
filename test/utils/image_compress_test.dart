import 'dart:math';
import 'dart:typed_data';

import 'package:bbarna/utils/image_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A photo-like opaque image (noise, so it does not compress to nothing).
Uint8List _opaquePng(int width, int height) {
  final Random random = Random(1);
  final img.Image image = img.Image(width: width, height: height);
  for (final img.Pixel p in image) {
    p
      ..r = random.nextInt(256)
      ..g = random.nextInt(256)
      ..b = random.nextInt(256);
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test('a large photo is scaled down and stored as JPEG', () async {
    final Uint8List original = _opaquePng(1600, 1000);
    final PreparedImage prepared =
        await prepareImageForUpload(original, maxSide: 800);

    expect(prepared.contentType, "image/jpeg");
    expect(prepared.bytes.lengthInBytes, lessThan(original.lengthInBytes));
    final img.Image out = img.decodeImage(prepared.bytes)!;
    expect(out.width, 800);
    expect(out.height, 500);
    // The size the student app keeps for it before it loads.
    expect(prepared.width, 800);
    expect(prepared.height, 500);
  });

  test('a small picture kept as it is still reports its size', () async {
    // Already small and compact: re-encoding would not make it smaller.
    final Uint8List original =
        Uint8List.fromList(img.encodePng(img.Image(width: 40, height: 30)));
    final PreparedImage prepared =
        await prepareImageForUpload(original, maxSide: 800);

    expect(prepared.bytes, same(original));
    expect(prepared.width, 40);
    expect(prepared.height, 30);
  });

  test('a picture with transparency stays PNG', () async {
    final img.Image image = img.Image(width: 1200, height: 600, numChannels: 4);
    for (final img.Pixel p in image) {
      p
        ..r = p.x % 256
        ..g = p.y % 256
        ..b = 90
        ..a = p.x < 600 ? 0 : 255;
    }
    final Uint8List original = Uint8List.fromList(img.encodePng(image));

    final PreparedImage prepared =
        await prepareImageForUpload(original, maxSide: 800);

    expect(prepared.contentType, "image/png");
    expect(img.decodeImage(prepared.bytes)!.width, 800);
  });

  test('bytes that are not an image are uploaded unchanged', () async {
    final Uint8List junk = Uint8List.fromList([1, 2, 3, 4, 5]);
    final PreparedImage prepared =
        await prepareImageForUpload(junk, maxSide: 800);

    expect(prepared.bytes, same(junk));
    expect(prepared.contentType, "image/jpeg");
    expect(prepared.width, 0); // unknown
    expect(prepared.height, 0);
  });

  test('content type is read from the file header', () {
    expect(sniffImageContentType(_opaquePng(4, 4)), "image/png");
    expect(
        sniffImageContentType(Uint8List.fromList(
            img.encodeJpg(img.Image(width: 4, height: 4)))),
        "image/jpeg");
  });
}
