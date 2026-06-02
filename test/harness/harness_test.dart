import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';
import 'image_diff.dart';
import 'render_widget.dart';

/// Phase 1 acceptance: the visual-diff harness machinery works.
///
/// These tests do NOT require a chart engine yet. They prove:
///   1. fixtures load and parse,
///   2. a widget can be rasterized to PNG at an exact size,
///   3. the perceptual diff detects identical vs. clearly-different images.
///
/// Once the Line chart lands (Phase 3) the per-fixture golden tests compare
/// `apex_dart` output against `test/golden/reference/<name>.png`.
void main() {
  group('fixtures', () {
    test('all 6 canonical fixtures load and parse', () {
      final fixtures = ChartFixture.loadAll();
      final names = fixtures.map((f) => f.name).toSet();
      expect(
        names,
        containsAll(<String>{
          'line_simple',
          'line_multi',
          'line_timeseries',
          'bar_grouped',
          'pie_basic',
          'donut_basic',
        }),
      );
      for (final f in fixtures) {
        expect(f.width, greaterThan(0));
        expect(f.height, greaterThan(0));
        expect(f.options['series'], isNotNull);
      }
    });
  });

  group('image diff machinery', () {
    testWidgets('identical renders diff to ~0%', (tester) async {
      final pngA = await rasterizeWidget(
        tester,
        const ColoredBox(color: Color(0xFF008FFB)),
        width: 100,
        height: 100,
      );
      final pngB = await rasterizeWidget(
        tester,
        const ColoredBox(color: Color(0xFF008FFB)),
        width: 100,
        height: 100,
      );

      late DiffResult result;
      await tester.runAsync(() async {
        final a = await ImageDiff.decodeBytes(pngA);
        final b = await ImageDiff.decodeBytes(pngB);
        result = ImageDiff.compare(a, b);
      });
      expect(result.withinTolerance(0.01), isTrue, reason: '$result');
    });

    testWidgets('clearly different renders exceed tolerance', (tester) async {
      final pngBlue = await rasterizeWidget(
        tester,
        const ColoredBox(color: Color(0xFF008FFB)),
        width: 100,
        height: 100,
      );
      final pngRed = await rasterizeWidget(
        tester,
        const ColoredBox(color: Color(0xFFFF0000)),
        width: 100,
        height: 100,
      );

      late DiffResult result;
      await tester.runAsync(() async {
        final blue = await ImageDiff.decodeBytes(pngBlue);
        final red = await ImageDiff.decodeBytes(pngRed);
        result = ImageDiff.compare(blue, red);
      });
      expect(result.fraction, greaterThan(0.5), reason: '$result');
    });

    testWidgets('size mismatch is penalised, not ignored', (tester) async {
      late DiffResult result;
      await tester.runAsync(() async {
        final small = await _solidRaster(10, 10, 0xFF008FFB);
        final big = await _solidRaster(20, 20, 0xFF008FFB);
        result = ImageDiff.compare(small, big);
      });
      // 100 overlapping identical px out of 400 total -> 75% mismatch.
      expect(result.fraction, greaterThan(0.5));
    });
  });
}

Future<Raster> _solidRaster(int w, int h, int argb) async {
  final bytes = Uint8List(w * h * 4);
  final a = (argb >> 24) & 0xff;
  final r = (argb >> 16) & 0xff;
  final g = (argb >> 8) & 0xff;
  final b = argb & 0xff;
  for (int i = 0; i < w * h; i++) {
    bytes[i * 4] = r;
    bytes[i * 4 + 1] = g;
    bytes[i * 4 + 2] = b;
    bytes[i * 4 + 3] = a;
  }
  final png = await _encode(bytes, w, h);
  return ImageDiff.decodeBytes(png);
}

Future<Uint8List> _encode(Uint8List rgba, int w, int h) async {
  final descriptor = ui.ImageDescriptor.raw(
    await ui.ImmutableBuffer.fromUint8List(rgba),
    width: w,
    height: h,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}
