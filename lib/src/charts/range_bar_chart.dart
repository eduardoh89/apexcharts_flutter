import 'dart:math' as math;
import 'dart:ui';

import '../modules/cartesian_layout.dart';
import '../options/apex_options.dart';

/// Renders range/timeline bars (Gantt-style), ported from ApexCharts v4.7.0
/// `src/charts/RangeBar.js` (which `extends Bar`). Each data point carries a
/// `[start, end]` value pair; the bar spans that range along the value axis.
///
/// apex_dart implements the common **horizontal timeline** orientation: rows
/// (data points) run down the Y axis (one band per point), and the value span
/// (`drawRangeBarPaths`: x1 = start, x2 = end) runs along X. When several
/// series share a row they are stacked as sub-rows within the band
/// (`barHeight = yDivision / seriesLen`, offset by the visible series index),
/// matching `RangeBar.drawRangeBarPaths` + `initialPositions`.
class RangeBarChartRenderer {
  const RangeBarChartRenderer._();

  static void paint(
    Canvas canvas,
    CartesianLayout layout,
    ApexOptions options,
  ) {
    final seriesLen = options.series.length;
    if (seriesLen == 0 || layout.pointCount == 0) return;

    // Map a value (start/end) to an x-pixel using the value-axis range, the
    // same mapping horizontal bars use (value axis is X).
    double valueToX(num v) {
      final span =
          (layout.yMax - layout.yMin) == 0 ? 1 : layout.yMax - layout.yMin;
      final t = (v - layout.yMin) / span;
      return layout.plotRect.left + t * layout.plotRect.width;
    }

    final double yDivision = layout.plotRect.height / layout.pointCount;
    // barHeight = (yDivision / seriesLen) * barHeight% (default 70%).
    final double barHeight =
        (yDivision / seriesLen) * options.bar.columnWidthFraction;
    final double groupPad = (yDivision - barHeight * seriesLen) / 2;

    for (int j = 0; j < layout.pointCount; j++) {
      final double bandTop = layout.plotRect.top + j * yDivision;
      for (int i = 0; i < seriesLen; i++) {
        final series = options.series[i];
        if (j >= series.points.length) continue;
        final p = series.points[j];
        if (p.isNull || !p.isRange) continue;

        final color = series.color ?? options.colors[i % options.colors.length];

        final double x1 = valueToX(math.min(p.y, p.yHigh!));
        final double x2 = valueToX(math.max(p.y, p.yHigh!));
        final double top = bandTop + groupPad + i * barHeight;

        final rect = Rect.fromLTRB(x1, top, x2, top + barHeight);
        final paint = Paint()
          ..style = PaintingStyle.fill
          ..color = color
          ..isAntiAlias = true;

        if (options.bar.borderRadius > 0) {
          final r = Radius.circular(options.bar.borderRadius);
          canvas.drawRRect(RRect.fromRectAndRadius(rect, r), paint);
        } else {
          canvas.drawRect(rect, paint);
        }
      }
    }
  }
}
