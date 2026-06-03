import 'dart:math' as math;
import 'dart:ui';

import '../modules/legend_renderer.dart';
import '../options/apex_options.dart';
import '../svg/text_drawer.dart';

/// Renders pie and donut charts.
///
/// Ported from ApexCharts v4.7.0 `src/charts/Pie.js`:
///   * total          = Σ max(value, 0)
///   * sliceAngle     = 360° * value / total
///   * starts at startAngle (default 0 → 12 o'clock) going clockwise
///   * radialSize     = min(w, h) / 2.05 − strokeWidth
///   * donutSize      = radialSize * donut.size%/100  (inner hole radius)
///   * data labels    = percentage, placed at the slice mid-angle, mid-radius
class PieChartRenderer {
  const PieChartRenderer._();

  /// White separator stroke between slices (ApexCharts default strokeWidth: 2).
  static const double _strokeWidth = 2;

  static void paint(Canvas canvas, Size size, ApexOptions options) {
    final values = options.pieSeries;
    if (values.isEmpty) return;

    // Reserve legend space so the pie centers in the remaining area.
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

    final area =
        Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    final centerX = area.center.dx;
    final centerY = area.center.dy;

    final double defaultSize = math.min(area.width, area.height);
    final double radialSize = defaultSize / 2.05 - _strokeWidth;
    final double donutInner = options.type == ApexChartType.donut
        ? radialSize * options.pie.donutSizeFraction
        : 0;

    double total = 0;
    for (final v in values) {
      total += v < 0 ? 0 : v;
    }
    if (total == 0) total = 0.00001;

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = _strokeWidth;

    // Start at 12 o'clock (-90°), clockwise.
    double startRad = -math.pi / 2;
    final center = Offset(centerX, centerY);

    for (int i = 0; i < values.length; i++) {
      final v = values[i] < 0 ? 0.0 : values[i];
      final sweep = 2 * math.pi * (v / total);
      final color = options.colors[i % options.colors.length];

      final path = Path()..moveTo(center.dx, center.dy);
      path.arcTo(
        Rect.fromCircle(center: center, radius: radialSize),
        startRad,
        sweep,
        false,
      );
      path.close();

      canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.fill);
      canvas.drawPath(path, strokePaint);

      startRad += sweep;
    }

    // Donut hole punched white (matches ApexCharts inner circle).
    if (donutInner > 0) {
      canvas.drawCircle(
        center,
        donutInner,
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.fill,
      );
    }

    if (options.dataLabelsEnabled) {
      _drawDataLabels(
        canvas,
        center,
        values,
        total,
        radialSize,
        donutInner,
        options,
      );
    }
  }

  static void _drawDataLabels(
    Canvas canvas,
    Offset center,
    List<double> values,
    double total,
    double radialSize,
    double donutInner,
    ApexOptions options,
  ) {
    // ApexCharts places pie labels at ~ (radius + donutInner)/2 along the
    // slice mid-angle; for a full pie that is radius*0.65-ish from center.
    final double labelRadius = options.type == ApexChartType.donut
        ? (radialSize + donutInner) / 2
        : radialSize * 0.65;

    final labeller = TextDrawer(
      color: const Color(0xFFFFFFFF),
      fontSize: 12,
      fontWeight: FontWeight.w600,
      fontFamily: options.fontFamily,
    );

    double startRad = -math.pi / 2;
    for (int i = 0; i < values.length; i++) {
      final v = values[i] < 0 ? 0.0 : values[i];
      final sweep = 2 * math.pi * (v / total);
      final mid = startRad + sweep / 2;
      final pct = (v / total) * 100;
      final label = '${pct.toStringAsFixed(1)}%';
      final lx = center.dx + labelRadius * math.cos(mid);
      final ly = center.dy + labelRadius * math.sin(mid);
      labeller.draw(
        canvas,
        label,
        Offset(lx, ly),
        anchor: TextAnchor.middle,
        verticalCenter: true,
      );
      startRad += sweep;
    }
  }
}
