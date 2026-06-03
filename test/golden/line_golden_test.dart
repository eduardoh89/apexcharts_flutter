import 'package:apexcharts_flutter/apexcharts_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/fixture.dart';
import '../harness/image_diff.dart';
import '../harness/render_widget.dart';

/// Phase 3 go/no-go: apex_dart line charts vs. real ApexCharts v4.7.0 renders.
///
/// We diff against the reference PNGs produced by tool/render_reference.mjs.
/// Tolerance is *perceptual* — SVG vs Skia text/anti-aliasing can never be
/// bit-identical, so we assert the mismatched-pixel fraction stays under a
/// threshold and emit a 3-up diff image on failure for eyeballing.
void main() {
  // Generous initial ceiling; tightened as fidelity improves. Charts with
  // axis text (which rasterizes very differently between engines) sit higher
  // than pure-geometry charts.
  const double kLineTolerance = 0.14;

  for (final name in ['line_simple', 'line_multi', 'line_timeseries']) {
    testWidgets('$name matches ApexCharts reference', (tester) async {
      final fixture = ChartFixture.load(name);

      if (!fixture.hasReference) {
        markTestSkipped(
          'No reference PNG for $name. Run: cd tool && node render_reference.mjs',
        );
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
        if (!result.withinTolerance(kLineTolerance)) {
          final path = await ImageDiff.writeSideBySide(
            name: name,
            reference: reference,
            candidate: candidate,
          );
          // ignore: avoid_print
          debugPrint('Diff for $name: $result -> $path');
        }
      });

      expect(
        result.withinTolerance(kLineTolerance),
        isTrue,
        reason: '$name diff $result exceeds tolerance $kLineTolerance',
      );
    });
  }
}
