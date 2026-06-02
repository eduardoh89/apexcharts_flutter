import 'dart:ui';

import '../modules/cartesian_layout.dart';
import '../options/apex_options.dart';

/// Renders column/bar charts: grouped or stacked, vertical or horizontal.
///
/// Ported from ApexCharts v4.7.0 `src/charts/Bar.js`, `BarStacked.js` and
/// `common/bar/Helpers.js`. Grouped column geometry (Helpers.initialPositions):
///   xDivision = plotWidth / dataPoints              (one band per category)
///   barWidth  = (xDivision / seriesLen) * columnWidth%/100
///   groupPad  = (xDivision - barWidth * seriesLen) / 2   (centers the group)
///   x(series i, cat j) = plotLeft + j*xDivision + groupPad + i*barWidth
/// For stacked, each series shares the full band width and accumulates on the
/// previous series' top (positive) / bottom (negative).
class BarChartRenderer {
  const BarChartRenderer._();

  static void paint(
    Canvas canvas,
    CartesianLayout layout,
    ApexOptions options,
  ) {
    final seriesLen = options.series.length;
    if (seriesLen == 0 || layout.pointCount == 0) return;

    if (options.bar.horizontal) {
      _paintHorizontal(canvas, layout, options);
      return;
    }
    if (options.stacked) {
      _paintStacked(canvas, layout, options);
      return;
    }
    _paintGrouped(canvas, layout, options);
  }

  static void _paintGrouped(
    Canvas canvas,
    CartesianLayout layout,
    ApexOptions options,
  ) {
    final seriesLen = options.series.length;
    final double xDivision = layout.bandWidth;
    final double barWidth =
        (xDivision / seriesLen) * options.bar.columnWidthFraction;
    final double groupPad = (xDivision - barWidth * seriesLen) / 2;
    final double baselineY = layout.yToPixel(0);

    for (int j = 0; j < layout.pointCount; j++) {
      final double bandLeft =
          layout.xBandCenter(j) - xDivision / 2 + groupPad;
      for (int i = 0; i < seriesLen; i++) {
        final series = options.series[i];
        if (j >= series.points.length) continue;
        final value = series.points[j].y;
        final color =
            series.color ?? options.colors[i % options.colors.length];

        final double left = bandLeft + i * barWidth;
        final double top = layout.yToPixel(value);
        final double rectTop = value >= 0 ? top : baselineY;
        final double rectBottom = value >= 0 ? baselineY : top;

        _fillBar(
          canvas,
          Rect.fromLTRB(left, rectTop, left + barWidth, rectBottom),
          color,
          options.bar.borderRadius,
          vertical: true,
        );
      }
    }
  }

  static void _paintStacked(
    Canvas canvas,
    CartesianLayout layout,
    ApexOptions options,
  ) {
    final seriesLen = options.series.length;
    final double xDivision = layout.bandWidth;
    final double barWidth = xDivision * options.bar.columnWidthFraction;
    final double bandPad = (xDivision - barWidth) / 2;

    for (int j = 0; j < layout.pointCount; j++) {
      final double left = layout.xBandCenter(j) - xDivision / 2 + bandPad;
      double posAcc = 0;
      double negAcc = 0;
      for (int i = 0; i < seriesLen; i++) {
        final series = options.series[i];
        if (j >= series.points.length) continue;
        final value = series.points[j].y;
        final color =
            series.color ?? options.colors[i % options.colors.length];

        final double base = value >= 0 ? posAcc : negAcc;
        final double topValue = base + value;
        final double yBase = layout.yToPixel(base);
        final double yTop = layout.yToPixel(topValue);
        if (value >= 0) {
          posAcc = topValue;
        } else {
          negAcc = topValue;
        }

        _fillBar(
          canvas,
          Rect.fromLTRB(
            left,
            value >= 0 ? yTop : yBase,
            left + barWidth,
            value >= 0 ? yBase : yTop,
          ),
          color,
          0,
          vertical: true,
        );
      }
    }
  }

  static void _paintHorizontal(
    Canvas canvas,
    CartesianLayout layout,
    ApexOptions options,
  ) {
    // Horizontal bars swap the roles of the axes. Our cartesian layout maps the
    // numeric scale to Y, so we re-map: value -> x via the y-tick range, and
    // categories -> evenly spaced bands down the plot height.
    final seriesLen = options.series.length;
    final double yDivision = layout.plotRect.height / layout.pointCount;

    // Map a data value to an x-pixel using the same min/max as the y-scale.
    double valueToX(num v) {
      final t = (v - layout.yMin) /
          ((layout.yMax - layout.yMin) == 0 ? 1 : layout.yMax - layout.yMin);
      return layout.plotRect.left + t * layout.plotRect.width;
    }

    final double baseX = valueToX(0);

    if (options.stacked) {
      for (int j = 0; j < layout.pointCount; j++) {
        final double bandTop = layout.plotRect.top + j * yDivision;
        final double barH = yDivision * options.bar.columnWidthFraction;
        final double pad = (yDivision - barH) / 2;
        double acc = 0;
        for (int i = 0; i < seriesLen; i++) {
          final series = options.series[i];
          if (j >= series.points.length) continue;
          final value = series.points[j].y;
          final color =
              series.color ?? options.colors[i % options.colors.length];
          final x0 = valueToX(acc);
          acc += value;
          final x1 = valueToX(acc);
          _fillBar(
            canvas,
            Rect.fromLTRB(x0 < x1 ? x0 : x1, bandTop + pad,
                x0 < x1 ? x1 : x0, bandTop + pad + barH),
            color,
            0,
            vertical: false,
          );
        }
      }
      return;
    }

    for (int j = 0; j < layout.pointCount; j++) {
      final double bandTop = layout.plotRect.top + j * yDivision;
      final double barH =
          (yDivision / seriesLen) * options.bar.columnWidthFraction;
      final double groupPad = (yDivision - barH * seriesLen) / 2;
      for (int i = 0; i < seriesLen; i++) {
        final series = options.series[i];
        if (j >= series.points.length) continue;
        final value = series.points[j].y;
        final color =
            series.color ?? options.colors[i % options.colors.length];
        final double top = bandTop + groupPad + i * barH;
        final double valX = valueToX(value);
        _fillBar(
          canvas,
          Rect.fromLTRB(
            value >= 0 ? baseX : valX,
            top,
            value >= 0 ? valX : baseX,
            top + barH,
          ),
          color,
          options.bar.borderRadius,
          vertical: false,
        );
      }
    }
  }

  static void _fillBar(
    Canvas canvas,
    Rect rect,
    Color color,
    double borderRadius, {
    required bool vertical,
  }) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color
      ..isAntiAlias = true;

    if (borderRadius > 0) {
      final r = Radius.circular(borderRadius);
      canvas.drawRRect(
        vertical
            ? RRect.fromRectAndCorners(rect, topLeft: r, topRight: r)
            : RRect.fromRectAndCorners(rect, topRight: r, bottomRight: r),
        paint,
      );
    } else {
      canvas.drawRect(rect, paint);
    }
  }
}
