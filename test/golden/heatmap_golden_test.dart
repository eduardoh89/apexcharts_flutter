import 'package:apexcharts_flutter/apexcharts_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/fixture.dart';
import '../harness/image_diff.dart';
import '../harness/render_widget.dart';

/// Phase 7 golden: heatmap vs. ApexCharts v4.7.0 (`HeatMap.js` +
/// `treemap/Helpers.getShadeColor`). Solid shaded cells; generous tolerance.
///
/// `heatmap_basic` is intentionally SKIPPED below rather than compared:
/// REVIA deliberately deviates from upstream's cell-shading formula (see the
/// doc comment on `HeatMapChartRenderer` in `heatmap_chart.dart` — a
/// low-but-real value no longer fades all the way to pure white, which is
/// what real ApexCharts does by default). That makes a pixel-diff against
/// the real ApexCharts reference PNG meaningless for this chart's cell
/// colors — a diff around ~68% is the *expected*, correct result of the
/// fix, not a regression. The intended REVIA shading behavior is verified
/// instead by `test/charts/heatmap_chart_test.dart`. Move a name back into
/// `activeTolerances` only for a heatmap variant whose colors are NOT
/// expected to diverge from upstream.
void main() {
  const activeTolerances = <String, double>{};
  const skipped = <String, String>{
    'heatmap_basic': 'REVIA deliberately deviates from upstream shading '
        '(see file doc comment) — verified by heatmap_chart_test.dart instead',
  };

  skipped.forEach((name, reason) {
    testWidgets(
      '$name matches ApexCharts reference (skipped: $reason)',
      (tester) async {},
      skip: true,
    );
  });

  activeTolerances.forEach((name, tolerance) {
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
