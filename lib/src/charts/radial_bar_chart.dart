import 'dart:math' as math;
import 'dart:ui';

import '../options/apex_options.dart';
import '../svg/text_drawer.dart';

/// Renders radialBar (circular gauge) charts, ported from ApexCharts v4.7.0
/// `src/charts/Radial.js` (which `extends Pie`).
///
/// Each series value (0..100, a percentage) becomes a concentric ring drawn as
/// a stroked arc from `startAngle` to `startAngle + totalAngle * value/100`,
/// over a light "track" ring. Geometry ported from `Radial`:
///   * size       = min(w,h)/2.05 - strokeWidth   (outer radius)
///   * strokeWidth= size * (100 - hollow.size%)/100 / (seriesLen + 1) - margin
///   * each ring i: size_i = size - strokeWidth/2 - i*(strokeWidth + margin)
///   * dataValue  = clamp(value, 0, 100) / 100
///   * endAngle   = round(totalAngle * dataValue) + startAngle
/// Angles use ApexCharts' `polarToCartesian` convention (0° at 12 o'clock,
/// clockwise), i.e. drawing angle = configAngle - 90°.
class RadialBarChartRenderer {
  const RadialBarChartRenderer._();

  /// Track ring color (`plotOptions.radialBar.track.background`, '#f2f2f2').
  static const Color _trackColor = Color(0xFFF2F2F2);

  static void paint(Canvas canvas, Size size, ApexOptions options) {
    final values = options.pieSeries;
    if (values.isEmpty) return;

    final radial = options.radialBar;
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double defaultSize = math.min(size.width, size.height);

    final double startAngle = radial.startAngle.toDouble();
    final double endAngleCfg = radial.endAngle.toDouble();
    final double totalAngle = (endAngleCfg - startAngle).abs();

    // Outer radius and per-ring stroke width (Radial.getStrokeWidth).
    final int seriesLen = values.length;
    final double margin = radial.trackMargin;
    final double outer = defaultSize / 2.05 - PieStrokeConstants.strokeWidth;
    final double strokeWidth =
        (outer * (100 - radial.hollowSizeFraction * 100) / 100) /
                (seriesLen + 1) -
            margin;

    final center = Offset(centerX, centerY);

    // Draw rings outermost → innermost. Radial decrements opts.size by
    // strokeWidth/2 once, then by (strokeWidth + margin) per series.
    double ringSize = outer - strokeWidth / 2;
    for (int i = 0; i < seriesLen; i++) {
      ringSize = ringSize - strokeWidth - margin;
      final double radius = ringSize;
      final color = options.colors[i % options.colors.length];

      // Track ring (full sweep).
      if (radial.trackShow) {
        _arc(canvas, center, radius, startAngle, startAngle + totalAngle,
            _trackColor, strokeWidth * radial.trackStrokeWidthFraction);
      }

      // Value arc.
      final double v = values[i] < 0
          ? 0
          : values[i] > 100
              ? 100
              : values[i];
      final double dataValue = v / 100;
      final double endAngle =
          (totalAngle * dataValue).roundToDouble() + startAngle;
      if (endAngle > startAngle) {
        _arc(canvas, center, radius, startAngle, endAngle, color, strokeWidth);
      }
    }

    // Center data labels (single-series value, or total). ApexCharts shows the
    // value formatted as "<v>%" by default.
    if (radial.dataLabelsShow) {
      _drawCenterLabels(canvas, center, values, options);
    }
  }

  /// Stroke an arc ring between two ApexCharts config angles (0° at top,
  /// clockwise). drawAngle = configAngle - 90°.
  static void _arc(
    Canvas canvas,
    Offset center,
    double radius,
    double startAngleDeg,
    double endAngleDeg,
    Color color,
    double width,
  ) {
    if (radius <= 0 || width <= 0) return;
    final double start = (startAngleDeg - 90) * math.pi / 180;
    final double sweep = (endAngleDeg - startAngleDeg) * math.pi / 180;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.butt
      ..color = color
      ..isAntiAlias = true;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      paint,
    );
  }

  static void _drawCenterLabels(
    Canvas canvas,
    Offset center,
    List<double> values,
    ApexOptions options,
  ) {
    // Single series: show its label (name) above its value. Multiple: show
    // "Total" above the average (ApexCharts `dataLabels.total` averages).
    final bool single = values.length == 1;
    final double display =
        single ? values.first : values.reduce((a, b) => a + b) / values.length;
    final String valueText = '${_fmt(display)}%';
    final String nameText = single
        ? (options.labels.isNotEmpty ? options.labels.first : '')
        : 'Total';

    // ApexCharts name default: 600 weight 16px (series color for single);
    // value default: 400 weight ~16px, offset +16 below the name.
    final Color nameColor =
        single ? options.colors.first : const Color(0xFF373D3F);
    final nameDrawer = TextDrawer(
      color: nameColor,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      fontFamily: options.fontFamily,
    );
    final valueDrawer = TextDrawer(
      color: const Color(0xFF373D3F),
      fontSize: 20,
      fontWeight: FontWeight.w400,
      fontFamily: options.fontFamily,
    );

    if (nameText.isNotEmpty) {
      nameDrawer.draw(canvas, nameText, center.translate(0, -10),
          anchor: TextAnchor.middle, verticalCenter: true);
      valueDrawer.draw(canvas, valueText, center.translate(0, 16),
          anchor: TextAnchor.middle, verticalCenter: true);
    } else {
      valueDrawer.draw(canvas, valueText, center,
          anchor: TextAnchor.middle, verticalCenter: true);
    }
  }

  static String _fmt(double v) {
    if (v == v.truncate()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

/// Shared with the pie renderer: ApexCharts' default inter-slice stroke width.
class PieStrokeConstants {
  static const double strokeWidth = 2;
}
