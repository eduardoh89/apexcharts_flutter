import 'dart:io';

import 'package:apex_dart/apex_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/fixture.dart';
import '../harness/image_diff.dart';
import '../harness/render_widget.dart';

/// Not a pass/fail test — always writes a 3-up (reference | apex_dart | diff)
/// image per fixture under test/golden/failures/ so the port can be eyeballed.
/// Run with: flutter test test/golden/_export_visual_test.dart
void main() {
  for (final name in [
    'line_simple',
    'line_multi',
    'line_timeseries',
    'bar_grouped',
    'pie_basic',
    'donut_basic',
  ]) {
    testWidgets('export $name', (tester) async {
      final fixture = ChartFixture.load(name);
      if (!fixture.hasReference) return;

      final png = await rasterizeWidget(
        tester,
        ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: ApexChart(
            options: ApexOptions.fromJson(fixture.options)
                .copyWith(fontFamily: 'Inter'),
          ),
        ),
        width: fixture.width,
        height: fixture.height,
      );

      await tester.runAsync(() async {
        final candidate = await ImageDiff.decodeBytes(png);
        final reference = await ImageDiff.decodeFile(fixture.referencePngPath);
        final result = ImageDiff.compare(reference, candidate);
        final path = await ImageDiff.writeSideBySide(
          name: name,
          reference: reference,
          candidate: candidate,
        );
        stdout.writeln('VISUAL $name -> $result -> $path');
      });
    });
  }
}
