import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Result of comparing two rasters.
class DiffResult {
  const DiffResult({
    required this.fraction,
    required this.mismatchedPixels,
    required this.totalPixels,
  });

  /// Fraction of pixels that differ beyond the per-channel threshold (0..1).
  final double fraction;
  final int mismatchedPixels;
  final int totalPixels;

  bool withinTolerance(double tolerance) => fraction <= tolerance;

  @override
  String toString() =>
      'DiffResult(${(fraction * 100).toStringAsFixed(2)}% '
      '$mismatchedPixels/$totalPixels px)';
}

/// Perceptual raster comparison used by the golden tests.
///
/// We deliberately do NOT require bit-identical output: SVG (ApexCharts) and
/// Skia (Flutter) rasterize text and anti-aliasing differently, so an exact
/// match is impossible. Instead we count pixels whose per-channel difference
/// exceeds [channelThreshold] and express that as a fraction of the image.
class ImageDiff {
  const ImageDiff._();

  /// Decode a PNG file into RGBA bytes + dimensions.
  static Future<Raster> decodeFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return decodeBytes(bytes);
  }

  static Future<Raster> decodeBytes(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final data =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return Raster(
      width: image.width,
      height: image.height,
      rgba: data!.buffer.asUint8List(),
    );
  }

  /// Compare two rasters. If sizes differ, the overlap region is compared and
  /// the non-overlapping area counts entirely as mismatch (so size drift is
  /// penalised, not silently ignored).
  static DiffResult compare(
    Raster a,
    Raster b, {
    int channelThreshold = 24,
  }) {
    final int w = a.width < b.width ? a.width : b.width;
    final int h = a.height < b.height ? a.height : b.height;
    final int maxW = a.width > b.width ? a.width : b.width;
    final int maxH = a.height > b.height ? a.height : b.height;
    final int totalPixels = maxW * maxH;

    int mismatched = (maxW * maxH) - (w * h); // non-overlapping pixels

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final int ia = (y * a.width + x) * 4;
        final int ib = (y * b.width + x) * 4;
        final int dr = (a.rgba[ia] - b.rgba[ib]).abs();
        final int dg = (a.rgba[ia + 1] - b.rgba[ib + 1]).abs();
        final int db = (a.rgba[ia + 2] - b.rgba[ib + 2]).abs();
        if (dr > channelThreshold ||
            dg > channelThreshold ||
            db > channelThreshold) {
          mismatched++;
        }
      }
    }

    return DiffResult(
      fraction: totalPixels == 0 ? 1.0 : mismatched / totalPixels,
      mismatchedPixels: mismatched,
      totalPixels: totalPixels,
    );
  }

  /// Write a 3-up diff image (reference | candidate | mismatch mask) for
  /// eyeballing failures. Saved under test/golden/failures/.
  static Future<String> writeSideBySide({
    required String name,
    required Raster reference,
    required Raster candidate,
    int channelThreshold = 24,
  }) async {
    final int w = reference.width < candidate.width
        ? reference.width
        : candidate.width;
    final int h = reference.height < candidate.height
        ? reference.height
        : candidate.height;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const gap = 8.0;

    final refImg = await reference.toImage();
    final candImg = await candidate.toImage();

    canvas.drawImage(refImg, ui.Offset.zero, ui.Paint());
    canvas.drawImage(
      candImg,
      ui.Offset(reference.width + gap, 0),
      ui.Paint(),
    );

    // Mismatch mask in the third column.
    final maskPaint = ui.Paint()..color = const ui.Color(0xFFFF0000);
    final double maskX = reference.width + candidate.width + gap * 2;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final int ir = (y * reference.width + x) * 4;
        final int ic = (y * candidate.width + x) * 4;
        final int dr = (reference.rgba[ir] - candidate.rgba[ic]).abs();
        final int dg = (reference.rgba[ir + 1] - candidate.rgba[ic + 1]).abs();
        final int db = (reference.rgba[ir + 2] - candidate.rgba[ic + 2]).abs();
        if (dr > channelThreshold ||
            dg > channelThreshold ||
            db > channelThreshold) {
          canvas.drawRect(
            ui.Rect.fromLTWH(maskX + x, y.toDouble(), 1, 1),
            maskPaint,
          );
        }
      }
    }

    final totalW =
        (reference.width + candidate.width + w).toDouble() + gap * 2;
    final totalH =
        [reference.height, candidate.height, h].reduce((a, b) => a > b ? a : b);
    final picture = recorder.endRecording();
    final img = await picture.toImage(totalW.ceil(), totalH);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);

    final dir = Directory('test/golden/failures');
    dir.createSync(recursive: true);
    final path = 'test/golden/failures/diff_$name.png';
    await File(path).writeAsBytes(png!.buffer.asUint8List());
    return path;
  }
}

/// A decoded RGBA raster.
class Raster {
  Raster({required this.width, required this.height, required this.rgba});
  final int width;
  final int height;
  final Uint8List rgba;

  Future<ui.Image> toImage() {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }
}
