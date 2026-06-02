import 'dart:ui';

import '../modules/cartesian_layout.dart';
import '../options/apex_options.dart';
import '../svg/paths.dart';

/// Renders line (and the line portion of area) series.
///
/// Ported from ApexCharts v4.7.0 `src/charts/Line.js`: each series becomes a
/// stroked path (straight / smooth / stepline) over the shared cartesian
/// layout. Markers are drawn only when the series is short enough that
/// ApexCharts would show them, matching the library's default
/// `markers.size: 0` (hidden) — we keep them off by default for line charts.
class LineChartRenderer {
  const LineChartRenderer._();

  static void paint(
    Canvas canvas,
    CartesianLayout layout,
    ApexOptions options,
  ) {
    for (int si = 0; si < options.series.length; si++) {
      final series = options.series[si];
      if (series.points.isEmpty) continue;
      final color = series.color ?? options.colors[si % options.colors.length];

      final pixelPoints = _pixelPoints(series, layout, options);

      if (options.type == ApexChartType.area) {
        final areaPath = ApexPaths.areaPath(
          pixelPoints,
          options.curve,
          layout.plotRect.bottom,
        );
        final fillPaint = Paint()
          ..style = PaintingStyle.fill
          ..shader = Gradient.linear(
            Offset(0, layout.plotRect.top),
            Offset(0, layout.plotRect.bottom),
            [
              color.withValues(alpha: 0.65),
              color.withValues(alpha: 0.05),
            ],
          );
        canvas.drawPath(areaPath, fillPaint);
      }

      final linePaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = color
        ..strokeWidth = options.strokeWidth
        ..strokeCap = StrokeCap.butt
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;

      final path = ApexPaths.linePath(pixelPoints, options.curve);
      canvas.drawPath(path, linePaint);

      // Static markers (ApexCharts markers.size; default 0 = hidden).
      final double mSize = options.markers.size;
      if (mSize > 0) {
        final fill = Paint()
          ..style = PaintingStyle.fill
          ..color = color
          ..isAntiAlias = true;
        final stroke = Paint()
          ..style = PaintingStyle.stroke
          ..color = options.markers.strokeColor
          ..strokeWidth = options.markers.strokeWidth
          ..isAntiAlias = true;
        for (final p in pixelPoints) {
          canvas.drawCircle(p, mSize, fill);
          canvas.drawCircle(p, mSize, stroke);
        }
      }
    }
  }

  static List<Offset> _pixelPoints(
    ApexSeries series,
    CartesianLayout layout,
    ApexOptions options,
  ) {
    final pts = <Offset>[];
    for (int i = 0; i < series.points.length; i++) {
      final p = series.points[i];
      final double x;
      if (options.xAxisType == ApexXAxisType.category) {
        x = layout.xCategoryToPixel(i);
      } else {
        x = layout.xValueToPixel(p.x ?? i.toDouble());
      }
      pts.add(Offset(x, layout.yToPixel(p.y)));
    }
    return pts;
  }
}
