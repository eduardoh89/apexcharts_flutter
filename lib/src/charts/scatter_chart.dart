import 'dart:math' as math;
import 'dart:ui';

import '../modules/cartesian_layout.dart';
import '../options/apex_options.dart';

/// Renders scatter and bubble plots — markers at each (x, y) with no
/// connecting line. Bubble radius is derived from the per-point z value.
///
/// Ported from ApexCharts v4.7.0 `src/charts/Scatter.js` (one class handles
/// both scatter and bubble) plus the z-ratio math from
/// `src/modules/CoreUtils.js` (`zRatio = (zRange / gridHeight) * 16`).
class ScatterChartRenderer {
  const ScatterChartRenderer._();

  static const double _markerRadius = 5;

  static void paint(
    Canvas canvas,
    CartesianLayout layout,
    ApexOptions options,
  ) {
    final bool isBubble = options.type == ApexChartType.bubble;

    // zRatio = (zRange / gridHeight) * 16 (CoreUtils.js). Falls back to 1 when
    // there is no z spread so the raw z is used directly.
    double zRatio = 1;
    if (isBubble) {
      double minZ = double.infinity, maxZ = -double.infinity;
      for (final s in options.series) {
        for (final p in s.points) {
          if (p.isNull || p.z == null) continue;
          minZ = math.min(minZ, p.z!);
          maxZ = math.max(maxZ, p.z!);
        }
      }
      if (minZ.isFinite && maxZ.isFinite) {
        final zRange = (maxZ - minZ).abs();
        final computed = (zRange / layout.plotRect.height) * 16;
        if (computed != 0) zRatio = computed;
      }
    }

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
        if (p.isNull) continue;
        final double x;
        if (options.xAxisType == ApexXAxisType.category) {
          x = layout.xCategoryToPixel(i);
        } else {
          x = layout.xValueToPixel(p.x ?? i.toDouble());
        }
        final center = Offset(x, layout.yToPixel(p.y));
        final double radius =
            isBubble ? _bubbleRadius(p.z, zRatio, options.bubble) : _markerRadius;
        if (radius <= 0) continue;
        canvas.drawCircle(center, radius, fill);
        canvas.drawCircle(center, radius, stroke);
      }
    }
  }

  /// Bubble radius from the z value, ported from `Scatter.js` `draw()`:
  /// radius = z; if zScaling: radius /= zRatio; then clamp to min/max.
  static double _bubbleRadius(
    double? z,
    double zRatio,
    ApexBubbleOptions bubble,
  ) {
    if (z == null) return 0;
    double radius = z;
    if (bubble.zScaling) radius /= zRatio;
    if (bubble.minBubbleRadius != null && radius < bubble.minBubbleRadius!) {
      radius = bubble.minBubbleRadius!;
    }
    if (bubble.maxBubbleRadius != null && radius > bubble.maxBubbleRadius!) {
      radius = bubble.maxBubbleRadius!;
    }
    return radius;
  }
}
