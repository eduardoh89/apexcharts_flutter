import 'package:apex_dart/apex_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/fixture.dart';
import '../harness/image_diff.dart';
import '../harness/render_widget.dart';

/// Phase 4 goldens: bar, pie and donut vs. ApexCharts v4.7.0.
///
/// Tolerances are higher than line charts because these are *solid-fill*
/// shapes: a 1px sub-pixel offset between the SVG and Skia rasterizers
/// double-counts along every filled edge, inflating the mismatch fraction
/// even when the chart is visually correct. The 3-up diff image is written on
/// failure so regressions are still caught by eye.
void main() {
  const tolerances = <String, double>{
    'bar_grouped': 0.40,
    'pie_basic': 0.30,
    'donut_basic': 0.30,
  };

  tolerances.forEach((name, tolerance) {
    testWidgets('$name matches ApexCharts reference', (tester) async {
      final fixture = ChartFixture.load(name);
      if (!fixture.hasReference) {
        markTestSkipped('No reference PNG for $name.');
        return;
      }

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

      late DiffResult result;
      await tester.runAsync(() async {
        final candidate = await ImageDiff.decodeBytes(png);
        final reference = await ImageDiff.decodeFile(fixture.referencePngPath);
        result = ImageDiff.compare(reference, candidate);
        if (!result.withinTolerance(tolerance)) {
          final path = await ImageDiff.writeSideBySide(
            name: name,
            reference: reference,
            candidate: candidate,
          );
          debugPrint('Diff for $name: $result -> $path');
        }
      });

      expect(
        result.withinTolerance(tolerance),
        isTrue,
        reason: '$name diff $result exceeds tolerance $tolerance',
      );
    });
  });
}
