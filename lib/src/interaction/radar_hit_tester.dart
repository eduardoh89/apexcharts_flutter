import 'dart:ui';

import '../charts/radar_chart.dart';
import '../options/apex_options.dart';
import '../utils/format_value.dart';
import 'chart_hit.dart';

/// Hit-testing for radar (spider) charts.
///
/// ApexCharts gives radar `tooltip.shared:false, intersect:true,
/// followCursor:true` (Defaults.radar), so the tooltip belongs to the single
/// data vertex nearest the cursor (within a small radius). We reuse the exact
/// vertex geometry the renderer draws (`RadarChartRenderer.geometry`) so the
/// tooltip marker and the plotted point coincide. The heading is the category
/// (axis) label; each series contributes one row at that point index — matching
/// how ApexCharts highlights the hovered vertex across series.
class RadarHitTester {
  RadarHitTester({required this.size, required this.options});

  final Size size;
  final ApexOptions options;

  static const double _maxRadius = 24;

  ChartHit? hitTest(Offset local) {
    final geo = RadarChartRenderer.geometry(size, options);
    if (geo == null) return null;

    double bestDist = double.infinity;
    int bestIndex = -1;
    Offset bestPos = Offset.zero;

    for (int i = 0; i < options.series.length; i++) {
      final s = options.series[i];
      for (int j = 0; j < s.points.length && j < geo.dataPointsLen; j++) {
        final p = s.points[j];
        if (p.isNull) continue;
        final pos = geo.pointPosition(p.y, j);
        final d = (pos - local).distance;
        if (d < bestDist) {
          bestDist = d;
          bestIndex = j;
          bestPos = pos;
        }
      }
    }

    if (bestIndex < 0 || bestDist > _maxRadius) return null;

    final String title = bestIndex < options.categories.length
        ? options.categories[bestIndex]
        : '${bestIndex + 1}';

    final rows = <TooltipSeriesValue>[];
    final markers = <MarkerPoint>[];
    for (int i = 0; i < options.series.length; i++) {
      final s = options.series[i];
      if (bestIndex >= s.points.length) continue;
      final p = s.points[bestIndex];
      if (p.isNull) continue;
      final color = s.color ?? options.colors[i % options.colors.length];
      rows.add(TooltipSeriesValue(
        color: color,
        seriesName: s.name.isEmpty ? 'Series ${i + 1}' : s.name,
        formattedValue: FormatValue.formatted(p.y, options.yFormat),
      ));
      markers.add(MarkerPoint(
        position: geo.pointPosition(p.y, bestIndex),
        color: color,
      ));
    }
    if (rows.isEmpty) return null;

    return ChartHit(
      title: title,
      rows: rows,
      anchor: bestPos,
      markerPoints: markers,
    );
  }
}
