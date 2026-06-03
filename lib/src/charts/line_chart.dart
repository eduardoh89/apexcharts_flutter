import 'dart:ui';

import '../modules/cartesian_layout.dart';
import '../options/apex_options.dart';
import '../svg/paths.dart';
import '../utils/apex_color.dart';

/// Renders line (and the line portion of area) series.
///
/// Ported from ApexCharts v4.7.0 `src/charts/Line.js`: each series becomes a
/// stroked path (straight / smooth / stepline) over the shared cartesian
/// layout. Null data points break the path into segments (ApexCharts leaves a
/// gap), `stroke.dashArray` dashes the line, and `markers.size` draws point
/// markers (default 0 = hidden for line/area).
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

      // Split into contiguous non-null segments so gaps break the path.
      final segments = _segments(series, layout, options);

      for (final seg in segments) {
        if (seg.isEmpty) continue;

        if (options.type == ApexChartType.area) {
          final areaPath = ApexPaths.areaPath(
            seg,
            options.curve,
            layout.plotRect.bottom,
          );
          // Vertical gradient fill (fill.gradient), ported from Fill.js +
          // Graphics.drawGradient: the base series color sits at one end and a
          // *shaded* variant (toward black for shade:'dark', white for
          // 'light') at the other. `inverseColors` (default true) puts the
          // shaded color at the top of the area and the base color at the
          // bottom — this is what gives the demo its lighter-top/deeper-bottom
          // blue band instead of a flat fill.
          final g = options.gradient;
          final double intensity =
              g.shade == 'dark' ? -g.shadeIntensity : g.shadeIntensity;
          final Color shaded = ApexColor.shade(color, intensity);
          Color topColor = color;
          Color bottomColor = shaded;
          if (g.inverseColors) {
            topColor = shaded;
            bottomColor = color;
          }
          final stop0 = (g.stops.isNotEmpty ? g.stops.first : 0) / 100.0;
          final stop1 = (g.stops.length > 1 ? g.stops[1] : 100) / 100.0;
          final fillPaint = Paint()
            ..style = PaintingStyle.fill
            ..shader = Gradient.linear(
              Offset(0, layout.plotRect.top),
              Offset(0, layout.plotRect.bottom),
              [
                topColor.withValues(alpha: g.opacityFrom),
                bottomColor.withValues(alpha: g.opacityTo),
              ],
              [stop0.clamp(0.0, 1.0), stop1.clamp(0.0, 1.0)],
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

        var path = ApexPaths.linePath(seg, options.curve);
        if (options.dashArray > 0) {
          path = _dashPath(path, options.dashArray, options.dashArray);
        }
        canvas.drawPath(path, linePaint);
      }

      // Static markers (ApexCharts markers.size; default 0 = hidden). Only on
      // real (non-null) data points.
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
        for (final seg in segments) {
          for (final p in seg) {
            canvas.drawCircle(p, mSize, fill);
            canvas.drawCircle(p, mSize, stroke);
          }
        }
      }
    }
  }

  /// Group the series points into runs of consecutive non-null values, mapped
  /// to pixel space.
  static List<List<Offset>> _segments(
    ApexSeries series,
    CartesianLayout layout,
    ApexOptions options,
  ) {
    final segments = <List<Offset>>[];
    var current = <Offset>[];
    for (int i = 0; i < series.points.length; i++) {
      final p = series.points[i];
      if (p.isNull) {
        if (current.isNotEmpty) {
          segments.add(current);
          current = <Offset>[];
        }
        continue;
      }
      final double x = options.xAxisType == ApexXAxisType.category
          ? layout.xCategoryToPixel(i)
          : layout.xValueToPixel(p.x ?? i.toDouble());
      current.add(Offset(x, layout.yToPixel(p.y)));
    }
    if (current.isNotEmpty) segments.add(current);
    return segments;
  }

  /// Convert a path into a dashed path with [dash]/[gap] lengths.
  static Path _dashPath(Path source, double dash, double gap) {
    final result = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final double len = draw ? dash : gap;
        if (draw) {
          result.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
    return result;
  }
}
