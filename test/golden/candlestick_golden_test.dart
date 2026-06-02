import 'package:apex_dart/apex_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/fixture.dart';
import '../harness/image_diff.dart';
import '../harness/render_widget.dart';

/// Phase 7 golden: candlestick (OHLC) vs. ApexCharts v4.7.0
/// (`BoxCandleStick.js`). Solid candle bodies + thin wicks; generous tolerance.
void main() {
  const tolerances = <String, double>{
    'candlestick_basic': 0.30,
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
