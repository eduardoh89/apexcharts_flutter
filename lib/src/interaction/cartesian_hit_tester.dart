import 'dart:math' as math;
import 'dart:ui';

import '../modules/cartesian_layout.dart';
import '../options/apex_options.dart';
import '../utils/format_value.dart';
import 'chart_hit.dart';

/// Hit-testing for line / area / bar / scatter charts.
///
/// Reproduces ApexCharts' default tooltip behaviour:
///   * line / area / bar (non-intersect): **shared** tooltip — snap to the
///     nearest x category and show every series at that index, with a vertical
///     crosshair and an active marker per series.
///   * scatter (intersect): tooltip for the single nearest marker only.
class CartesianHitTester {
  CartesianHitTester({
    required this.layout,
    required this.options,
  });

  final CartesianLayout layout;
  final ApexOptions options;

  /// Returns the tooltip data for pointer position [local], or null when the
  /// pointer is outside the plot or there is no data.
  ChartHit? hitTest(Offset local) {
    if (options.series.isEmpty || layout.pointCount == 0) return null;

    // Allow a small vertical slop outside the plot so the tooltip does not
    // flicker at the edges, but require x within the plot horizontally.
    if (local.dx < layout.plotRect.left - 4 ||
        local.dx > layout.plotRect.right + 4) {
      return null;
    }

    if (options.type == ApexChartType.scatter) {
      return _intersectNearest(local);
    }
    if (options.type == ApexChartType.bar && options.bar.horizontal) {
      return _sharedHorizontalBar(local);
    }
    return _sharedByXIndex(local);
  }

  // Shared tooltip: find nearest category index to the cursor x.
  ChartHit? _sharedByXIndex(Offset local) {
    int nearest = 0;
    double bestDist = double.infinity;
    final bool banded = options.type == ApexChartType.bar;

    for (int j = 0; j < layout.pointCount; j++) {
      final double x =
          banded ? layout.xBandCenter(j) : _xForIndex(j);
      final d = (x - local.dx).abs();
      if (d < bestDist) {
        bestDist = d;
        nearest = j;
      }
    }

    final double focusX =
        banded ? layout.xBandCenter(nearest) : _xForIndex(nearest);

    final rows = <TooltipSeriesValue>[];
    final markers = <MarkerPoint>[];
    for (int i = 0; i < options.series.length; i++) {
      final s = options.series[i];
      if (nearest >= s.points.length) continue;
      final value = s.points[nearest].y;
      final color = s.color ?? options.colors[i % options.colors.length];
      rows.add(TooltipSeriesValue(
        color: color,
        seriesName: s.name.isEmpty ? 'Series ${i + 1}' : s.name,
        formattedValue: FormatValue.formatted(value, options.yFormat),
      ));
      if (!banded) {
        markers.add(MarkerPoint(
          position: Offset(focusX, layout.yToPixel(value)),
          color: color,
        ));
      }
    }
    if (rows.isEmpty) return null;

    return ChartHit(
      title: _titleForIndex(nearest),
      rows: rows,
      anchor: Offset(focusX, _anchorYForIndex(nearest)),
      markerPoints: markers,
      crosshairX: focusX,
    );
  }

  // Horizontal bar: snap to nearest category band on the Y axis.
  ChartHit? _sharedHorizontalBar(Offset local) {
    final double yDivision = layout.plotRect.height / layout.pointCount;
    int nearest =
        ((local.dy - layout.plotRect.top) / yDivision).floor();
    nearest = nearest.clamp(0, layout.pointCount - 1);

    final rows = <TooltipSeriesValue>[];
    for (int i = 0; i < options.series.length; i++) {
      final s = options.series[i];
      if (nearest >= s.points.length) continue;
      final color = s.color ?? options.colors[i % options.colors.length];
      rows.add(TooltipSeriesValue(
        color: color,
        seriesName: s.name.isEmpty ? 'Series ${i + 1}' : s.name,
        formattedValue:
            FormatValue.formatted(s.points[nearest].y, options.yFormat),
      ));
    }
    if (rows.isEmpty) return null;

    final double bandCenterY =
        layout.plotRect.top + yDivision * (nearest + 0.5);
    return ChartHit(
      title: _titleForIndex(nearest),
      rows: rows,
      anchor: Offset(local.dx.clamp(layout.plotRect.left, layout.plotRect.right),
          bandCenterY),
    );
  }

  // Intersect mode (scatter): nearest single marker within a radius.
  ChartHit? _intersectNearest(Offset local) {
    const double maxRadius = 24;
    double bestDist = double.infinity;
    int bestSeries = -1;
    int bestIndex = -1;
    Offset bestPos = Offset.zero;

    for (int i = 0; i < options.series.length; i++) {
      final s = options.series[i];
      for (int j = 0; j < s.points.length; j++) {
        final p = s.points[j];
        final double x = options.xAxisType == ApexXAxisType.category
            ? _xForIndex(j)
            : layout.xValueToPixel(p.x ?? j.toDouble());
        final pos = Offset(x, layout.yToPixel(p.y));
        final d = (pos - local).distance;
        if (d < bestDist) {
          bestDist = d;
          bestSeries = i;
          bestIndex = j;
          bestPos = pos;
        }
      }
    }

    if (bestSeries < 0 || bestDist > maxRadius) return null;

    final s = options.series[bestSeries];
    final p = s.points[bestIndex];
    final color =
        s.color ?? options.colors[bestSeries % options.colors.length];
    final String title = p.x == null
        ? '${bestIndex + 1}'
        : FormatValue.number(p.x!);

    return ChartHit(
      title: title,
      rows: [
        TooltipSeriesValue(
          color: color,
          seriesName: s.name.isEmpty ? 'Series ${bestSeries + 1}' : s.name,
          formattedValue: FormatValue.formatted(p.y, options.yFormat),
          highlighted: true,
        ),
      ],
      anchor: bestPos,
      markerPoints: [MarkerPoint(position: bestPos, color: color)],
    );
  }

  double _xForIndex(int index) => layout.xCategoryToPixel(index);

  // For the crosshair anchor we use the highest (min-y-pixel) series value so
  // the tooltip sits near the top of the stack of points.
  double _anchorYForIndex(int index) {
    double minY = double.infinity;
    for (final s in options.series) {
      if (index < s.points.length) {
        minY = math.min(minY, layout.yToPixel(s.points[index].y));
      }
    }
    return minY.isFinite ? minY : layout.plotRect.center.dy;
  }

  String _titleForIndex(int index) {
    if (options.xAxisType == ApexXAxisType.category) {
      if (index < options.categories.length) {
        return options.categories[index];
      }
      return '${index + 1}';
    }
    // datetime / numeric: title from the first series' x at this index.
    for (final s in options.series) {
      if (index < s.points.length && s.points[index].x != null) {
        final x = s.points[index].x!;
        return options.xAxisType == ApexXAxisType.datetime
            ? FormatValue.dateTitle(x)
            : FormatValue.number(x);
      }
    }
    return '${index + 1}';
  }
}
