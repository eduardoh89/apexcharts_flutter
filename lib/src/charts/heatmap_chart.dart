import 'dart:math' as math;
import 'dart:ui';

import '../options/apex_options.dart';
import '../svg/text_drawer.dart';
import '../utils/apex_color.dart';

/// Renders heatmap charts, ported from ApexCharts v4.7.0 `src/charts/HeatMap.js`
/// + the color logic in `charts/common/treemap/Helpers.js`.
///
/// Grid: each series is a row, each category a column.
///   * xDivision = gridWidth / dataPoints, yDivision = gridHeight / seriesLen
///   * series[0] is drawn at the BOTTOM (the upstream loop walks series from
///     last to first while y increases from the top).
/// Cell color (`getShadeColor`, non-negative default path):
///   * percent = 100 * val / (|maxY| + |minY|)
///   * colorShadePercent = 1 - percent/100
///   * color = shadeColor(colorShadePercent, paletteColor[rowIndex])
///     (positive shade lightens toward white) at `fill.opacity` (default 1).
/// So high values stay near the full palette color; low values fade to white.
class HeatMapChartRenderer {
  const HeatMapChartRenderer._();

  static const double _leftGutterMin = 50;
  static const double _bottomGutter = 30;
  static const double _topPadding = 10;
  static const double _rightPadding = 12;

  static void paint(Canvas canvas, Size size, ApexOptions options) {
    final series = options.series;
    if (series.isEmpty) return;
    int dataPoints = 0;
    for (final s in series) {
      dataPoints = math.max(dataPoints, s.points.length);
    }
    if (dataPoints == 0) return;

    // Global min/max across all cells (non-distributed default).
    double minY = double.infinity, maxY = -double.infinity;
    for (final s in series) {
      for (final p in s.points) {
        if (p.isNull) continue;
        minY = math.min(minY, p.y);
        maxY = math.max(maxY, p.y);
      }
    }
    if (!minY.isFinite) {
      minY = 0;
      maxY = 1;
    }
    final double total = (maxY.abs() + minY.abs()) == 0
        ? -0.000001
        : maxY.abs() + minY.abs();

    final double shadeIntensity = options.heatmap.shadeIntensity;
    final bool hasNegs = minY < 0;

    // Reserve gutters: left for row (series) labels, bottom for category labels.
    final labeller = TextDrawer(
      color: const Color(0xFF6E8192),
      fontSize: 11,
      fontFamily: options.fontFamily,
    );
    double widestRow = 0;
    for (final s in series) {
      widestRow = math.max(widestRow, labeller.measure(s.name).width);
    }
    final double leftGutter = math.max(_leftGutterMin, widestRow + 16);

    final plot = Rect.fromLTRB(
      leftGutter,
      _topPadding,
      size.width - _rightPadding,
      size.height - _bottomGutter,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    final double xDivision = plot.width / dataPoints;
    final double yDivision = plot.height / series.length;
    final double radius = options.heatmap.radius;

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFFFFFFF);

    final dataLabeller = TextDrawer(
      color: const Color(0xFFFFFFFF),
      fontSize: 11,
      fontFamily: options.fontFamily,
    );

    for (int i = 0; i < series.length; i++) {
      final s = series[i];
      // series[0] at the bottom: row from the top is (seriesLen-1 - i).
      final int rowFromTop = series.length - 1 - i;
      final double y1 = plot.top + rowFromTop * yDivision;
      final baseColor = s.color ?? options.colors[i % options.colors.length];

      for (int j = 0; j < dataPoints; j++) {
        if (j >= s.points.length) continue;
        final p = s.points[j];
        if (p.isNull) continue;
        final double x1 = plot.left + j * xDivision;

        final double percent = 100 * p.y / total;
        final Color cellColor = options.heatmap.enableShades
            ? _shadeFor(baseColor, percent, hasNegs, shadeIntensity)
            : baseColor;

        final rect = Rect.fromLTWH(x1, y1, xDivision, yDivision);
        final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
        canvas.drawRRect(rrect, Paint()..color = cellColor..isAntiAlias = true);
        canvas.drawRRect(rrect, strokePaint);

        if (options.dataLabelsEnabled) {
          dataLabeller.draw(
            canvas,
            _fmtNum(p.y),
            Offset(x1 + xDivision / 2, y1 + yDivision / 2),
            anchor: TextAnchor.middle,
            verticalCenter: true,
          );
        }
      }

      // Row label (series name) at the left, vertically centered on the row.
      labeller.draw(
        canvas,
        s.name,
        Offset(plot.left - 10, y1 + yDivision / 2),
        anchor: TextAnchor.end,
        verticalCenter: true,
      );
    }

    // Category (x) labels along the bottom, centered under each column.
    final double labelY = plot.bottom + 8;
    for (int j = 0; j < dataPoints; j++) {
      final lbl = j < options.categories.length ? options.categories[j] : '';
      if (lbl.isEmpty) continue;
      labeller.draw(
        canvas,
        lbl,
        Offset(plot.left + (j + 0.5) * xDivision, labelY),
        anchor: TextAnchor.middle,
      );
    }
  }

  /// Cell shade (non-negative default path of `getShadeColor`).
  static Color _shadeFor(
    Color base,
    double percent,
    bool hasNegs,
    double shadeIntensity,
  ) {
    double colorShadePercent;
    if (hasNegs) {
      if (percent <= 0) {
        colorShadePercent = 1 - (1 + percent / 100) * shadeIntensity;
      } else {
        colorShadePercent = (1 - percent / 100) * shadeIntensity;
      }
    } else {
      colorShadePercent = 1 - percent / 100;
    }
    // shadeColor: positive lightens toward white (light theme default).
    return ApexColor.shade(base, colorShadePercent);
  }

  static String _fmtNum(double v) {
    if (v == v.truncate()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}
