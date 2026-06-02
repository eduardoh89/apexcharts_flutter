import 'dart:ui';

import '../modules/cartesian_layout.dart';
import '../options/apex_options.dart';

/// Renders scatter plots — markers at each (x, y) with no connecting line.
///
/// Ported from ApexCharts v4.7.0 `src/charts/Scatter.js` default marker
/// (filled circle, size 6, white 1px stroke).
class ScatterChartRenderer {
  const ScatterChartRenderer._();

  static const double _markerRadius = 5;

  static void paint(
    Canvas canvas,
    CartesianLayout layout,
    ApexOptions options,
  ) {
    for (int si = 0; si < options.series.length; si++) {
      final series = options.series[si];
      final color = series.color ?? options.colors[si % options.colors.length];

      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = color
        ..isAntiAlias = true;
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFFFFFFFF)
        ..strokeWidth = 1
        ..isAntiAlias = true;

      for (int i = 0; i < series.points.length; i++) {
        final p = series.points[i];
        final double x;
        if (options.xAxisType == ApexXAxisType.category) {
          x = layout.xCategoryToPixel(i);
        } else {
          x = layout.xValueToPixel(p.x ?? i.toDouble());
        }
        final center = Offset(x, layout.yToPixel(p.y));
        canvas.drawCircle(center, _markerRadius, fill);
        canvas.drawCircle(center, _markerRadius, stroke);
      }
    }
  }
}
