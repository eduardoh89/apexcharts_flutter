import 'dart:math' as math;
import 'dart:ui';

import '../modules/cartesian_layout.dart';
import '../options/apex_options.dart';

/// Renders candlestick (OHLC) charts, ported from ApexCharts v4.7.0
/// `src/charts/BoxCandleStick.js` (`drawVerticalBoxPaths`, regular candlestick
/// branch).
///
/// Each point carries `[open, high, low, close]`. Per candle:
///   * body spans [min(open,close) .. max(open,close)] across the bar width
///   * the wick is a vertical line at the candle center from high to low
///   * color = upward (`#00B746`) when close ≥ open, else downward (`#EF403C`)
/// Bar width follows the grouped-column geometry (`bar.columnWidth`, default
/// 70% of the category band).
class CandlestickChartRenderer {
  const CandlestickChartRenderer._();

  static const Color _upward = Color(0xFF00B746);
  static const Color _downward = Color(0xFFEF403C);

  static void paint(
    Canvas canvas,
    CartesianLayout layout,
    ApexOptions options,
  ) {
    if (options.series.isEmpty || layout.pointCount == 0) return;

    final upColor = options.candlestick.upwardColor ?? _upward;
    final downColor = options.candlestick.downwardColor ?? _downward;

    // Single OHLC series per chart (ApexCharts candlestick is one series).
    final series = options.series.first;

    // Slot width from the visible point count (works for both index-based and
    // datetime/numeric domains, where bandWidth is in domain units).
    final bool valueX = options.xAxisType == ApexXAxisType.datetime ||
        options.xAxisType == ApexXAxisType.numeric;
    final double slot = valueX
        ? layout.plotRect.width / math.max(layout.pointCount, 1)
        : layout.bandWidth;
    final double barWidth = slot * options.bar.columnWidthFraction;
    // For a value (datetime/numeric) x-axis the first/last points map to the
    // plot edges; inset each candle center by half a slot so edge candles sit
    // fully inside the plot like ApexCharts' band layout.
    final double inset = valueX ? slot / 2 : 0;

    for (int j = 0; j < series.points.length; j++) {
      final p = series.points[j];
      if (p.isNull || !p.isOhlc) continue;
      final o = p.ohlc![0];
      final h = p.ohlc![1];
      final l = p.ohlc![2];
      final c = p.ohlc![3];

      final bool up = c >= o;
      final color = up ? upColor : downColor;

      double centerX = _centerX(layout, options, p, j);
      // Compress the edge-to-edge value mapping inward by `inset` on each side.
      if (inset > 0 && layout.plotRect.width > 0) {
        final double frac =
            (centerX - layout.plotRect.left) / layout.plotRect.width;
        centerX = layout.plotRect.left +
            inset +
            frac * (layout.plotRect.width - 2 * inset);
      }
      final double left = centerX - barWidth / 2;

      // Body: open..close.
      final double yOpen = layout.yToPixel(o);
      final double yClose = layout.yToPixel(c);
      final double bodyTop = math.min(yOpen, yClose);
      final double bodyBottom = math.max(yOpen, yClose);

      // Wick: high..low at the center.
      final double yHigh = layout.yToPixel(h);
      final double yLow = layout.yToPixel(l);

      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color
        ..isAntiAlias = true;
      final wickPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color
        ..isAntiAlias = true;

      canvas.drawLine(Offset(centerX, yHigh), Offset(centerX, yLow), wickPaint);

      // Body rect; guard against a zero-height doji (draw a thin line).
      final double bh = (bodyBottom - bodyTop).abs();
      if (bh < 1) {
        canvas.drawLine(
          Offset(left, bodyTop),
          Offset(left + barWidth, bodyTop),
          wickPaint,
        );
      } else {
        canvas.drawRect(
          Rect.fromLTRB(left, bodyTop, left + barWidth, bodyBottom),
          fillPaint,
        );
      }
    }
  }

  static double _centerX(
    CartesianLayout layout,
    ApexOptions options,
    ApexPoint p,
    int j,
  ) {
    if (options.xAxisType == ApexXAxisType.datetime ||
        options.xAxisType == ApexXAxisType.numeric) {
      return layout.xValueToPixel(p.x ?? j.toDouble());
    }
    return layout.xBandCenter(j);
  }
}
