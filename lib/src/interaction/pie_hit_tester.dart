import 'dart:math' as math;
import 'dart:ui';

import '../modules/legend_renderer.dart';
import '../options/apex_options.dart';
import '../utils/format_value.dart';
import 'chart_hit.dart';

/// Hit-testing for pie / donut charts: determine which slice the pointer is
/// over by radius + angle, matching the geometry in `PieChartRenderer`.
class PieHitTester {
  PieHitTester({required this.size, required this.options});

  final Size size;
  final ApexOptions options;

  ChartHit? hitTest(Offset local) {
    final values = options.pieSeries;
    if (values.isEmpty) return null;

    // Mirror PieChartRenderer's legend-aware centering.
    final pos = options.legend.position;
    double left = 0, top = 0, right = 0, bottom = 0;
    if (pos == ApexLegendPosition.right) {
      right = LegendRenderer.reservedWidth(options);
    } else if (pos == ApexLegendPosition.left) {
      left = LegendRenderer.reservedWidth(options);
    } else if (pos == ApexLegendPosition.bottom) {
      bottom = 26;
    } else if (pos == ApexLegendPosition.top) {
      top = 26;
    }

    final area = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    final center = area.center;
    final double defaultSize = math.min(area.width, area.height);
    const double strokeWidth = 2;
    final double radialSize = defaultSize / 2.05 - strokeWidth;
    final double donutInner = options.type == ApexChartType.donut
        ? radialSize * options.pie.donutSizeFraction
        : 0;

    final dist = (local - center).distance;
    if (dist > radialSize || dist < donutInner) return null;

    double total = 0;
    for (final v in values) {
      total += v < 0 ? 0 : v;
    }
    if (total == 0) return null;

    // Angle of the pointer, measured clockwise from 12 o'clock (-pi/2), in
    // [0, 2pi) to match the slice sweep accumulation.
    double angle = math.atan2(local.dy - center.dy, local.dx - center.dx) +
        math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;

    double acc = 0;
    for (int i = 0; i < values.length; i++) {
      final v = values[i] < 0 ? 0.0 : values[i];
      final sweep = 2 * math.pi * (v / total);
      if (angle >= acc && angle < acc + sweep) {
        final color = options.colors[i % options.colors.length];
        final label = i < options.labels.length
            ? options.labels[i]
            : 'Slice ${i + 1}';
        // Anchor at the slice mid-angle on the outer radius.
        final mid = -math.pi / 2 + acc + sweep / 2;
        final anchor = Offset(
          center.dx + radialSize * 0.8 * math.cos(mid),
          center.dy + radialSize * 0.8 * math.sin(mid),
        );
        return ChartHit(
          title: label,
          rows: [
            TooltipSeriesValue(
              color: color,
              seriesName: label,
              formattedValue: FormatValue.formatted(v, options.yFormat),
              highlighted: true,
            ),
          ],
          anchor: anchor,
        );
      }
      acc += sweep;
    }
    return null;
  }
}
