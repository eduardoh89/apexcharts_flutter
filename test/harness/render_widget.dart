import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] at an exact logical size and rasterizes it to PNG bytes,
/// so an `apex_dart` chart can be diffed against an ApexCharts reference PNG.
///
/// Uses a [RepaintBoundary] + `toImage` at devicePixelRatio = 1 to match the
/// reference renderer (`tool/render_reference.mjs` runs at DPR 1).
Future<Uint8List> rasterizeWidget(
  WidgetTester tester,
  Widget child, {
  required double width,
  required double height,
}) async {
  final key = GlobalKey();

  await tester.pumpWidget(
    Center(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: width,
            height: height,
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

  // Image rasterization uses real async (engine callbacks) that the fake-async
  // test zone does not pump, so it must run inside runAsync.
  late Uint8List bytes;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    bytes = data!.buffer.asUint8List();
  });
  return bytes;
}
