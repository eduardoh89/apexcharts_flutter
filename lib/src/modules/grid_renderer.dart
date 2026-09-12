import 'dart:math' as math;
import 'dart:ui';

import '../options/apex_options.dart';
import '../svg/text_drawer.dart';
import '../utils/format_value.dart';
import '../utils/range.dart';
import 'cartesian_layout.dart';
import 'time_scale.dart';

/// Draws the cartesian chart chrome: horizontal gridlines, y-axis labels and
/// x-axis labels. Mirrors ApexCharts' default light theme:
///   * gridlines  #e0e6ed (borderColor)
///   * axis labels #6e8192-ish, 11px
class GridRenderer {
  const GridRenderer._();

  static const Color _gridLine = Color(0xFFE0E6ED);
  static const Color _labelColor = Color(0xFF373D3F);

  static void paint(
    Canvas canvas,
    CartesianLayout layout,
    ApexOptions options,
  ) {
    final gridPaint = Paint()
      ..color = _gridLine
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final labeller = TextDrawer(
      color: _labelColor.withValues(alpha: 0.85),
      fontFamily: options.fontFamily,
    );

    // Range/timeline bars invert the axes: value ticks (often datetime) run
    // along X at the bottom, row labels run down the Y axis.
    if (options.type == ApexChartType.rangeBar) {
      _paintRangeBarGrid(canvas, layout, options, gridPaint, labeller);
      _paintAxisTitles(canvas, layout, options);
      return;
    }

    // Horizontal gridlines + y labels at each tick.
    for (final tick in layout.yTicks) {
      final y = layout.yToPixel(tick);
      canvas.drawLine(
        Offset(layout.plotRect.left, y),
        Offset(layout.plotRect.right, y),
        gridPaint,
      );
      // For horizontal bars the value axis is X, not Y — skip y-tick value
      // labels there (the category labels are drawn along Y instead).
      final String yLabel = options.bar.horizontal
          ? _fmtNum(tick)
          : FormatValue.formatted(tick, options.yFormat);
      labeller.draw(
        canvas,
        yLabel,
        Offset(layout.plotRect.left - 10, y),
        anchor: TextAnchor.end,
        verticalCenter: true,
      );
    }

    _paintXLabels(canvas, layout, options, labeller);
    _paintAxisTitles(canvas, layout, options);
  }

  /// Range/timeline grid: vertical value gridlines + X labels along the bottom
  /// (datetime-formatted when the value axis is datetime), and one row label
  /// per data point down the Y axis (`RangeBar` swaps the axes vs. a column).
  static void _paintRangeBarGrid(
    Canvas canvas,
    CartesianLayout layout,
    ApexOptions options,
    Paint gridPaint,
    TextDrawer labeller,
  ) {
    final double span =
        (layout.yMax - layout.yMin) == 0 ? 1 : layout.yMax - layout.yMin;
    double valueToX(num v) =>
        layout.plotRect.left +
        ((v - layout.yMin) / span) * layout.plotRect.width;

    final double labelY = layout.plotRect.bottom + 8;
    final bool datetime = options.xAxisType == ApexXAxisType.datetime;

    if (datetime) {
      final ticks = TimeScale.ticks(
        layout.yMin,
        layout.yMax,
        tickAmount: options.tickAmount,
        gridWidth: layout.plotRect.width,
      );
      for (final tick in ticks) {
        final x = valueToX(tick.ms);
        if (x < layout.plotRect.left - 1 || x > layout.plotRect.right + 1) {
          continue;
        }
        canvas.drawLine(Offset(x, layout.plotRect.top),
            Offset(x, layout.plotRect.bottom), gridPaint);
        labeller.draw(canvas, tick.label, Offset(x, labelY),
            anchor: TextAnchor.middle);
      }
    } else {
      for (final tick in layout.yTicks) {
        final x = valueToX(tick);
        canvas.drawLine(Offset(x, layout.plotRect.top),
            Offset(x, layout.plotRect.bottom), gridPaint);
        labeller.draw(canvas, _fmtNum(tick), Offset(x, labelY),
            anchor: TextAnchor.middle);
      }
    }

    // Row labels down the Y axis: one per data point, taken from the point's
    // carried label (timeline `{ x: 'Task' }`) or the configured categories.
    final int n = layout.pointCount;
    final double yDivision = n > 0 ? layout.plotRect.height / n : 0;
    final series = options.series.isNotEmpty ? options.series.first : null;
    for (int j = 0; j < n; j++) {
      String? label;
      if (series != null && j < series.points.length) {
        label = series.points[j].label;
      }
      label ??= j < layout.xCategories.length ? layout.xCategories[j] : '';
      final double cy = layout.plotRect.top + (j + 0.5) * yDivision;
      labeller.draw(
        canvas,
        label,
        Offset(layout.plotRect.left - 10, cy),
        anchor: TextAnchor.end,
        verticalCenter: true,
      );
    }
  }

  static void _paintAxisTitles(
    Canvas canvas,
    CartesianLayout layout,
    ApexOptions options,
  ) {
    final titleDrawer = TextDrawer(
      color: _labelColor,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      fontFamily: options.fontFamily,
    );

    if (options.xTitle.hasText) {
      // 26px below plotRect.bottom is only enough clearance for the flat,
      // single-line case. plotRect.bottom moving up makes ROOM for rotated
      // labels, but doesn't by itself keep the title below them — the title
      // needs its own offset to grow by the same amount
      // (xLabelsExtraGutter), or a long rotated label (which can reach
      // 70px down, not the old 34px) still reaches exactly where a flat
      // +26 puts this title.
      titleDrawer.draw(
        canvas,
        options.xTitle.text!,
        Offset(
          layout.plotRect.center.dx,
          layout.plotRect.bottom + 26 + layout.xLabelsExtraGutter,
        ),
        anchor: TextAnchor.middle,
      );
    }

    if (options.yTitle.hasText) {
      // Rotated -90° along the left edge, vertically centered on the plot.
      titleDrawer.draw(
        canvas,
        options.yTitle.text!,
        Offset(14, layout.plotRect.center.dy),
        anchor: TextAnchor.middle,
        rotation: -1.5707963267948966, // -pi/2
      );
    }
  }

  static void _paintXLabels(
    Canvas canvas,
    CartesianLayout layout,
    ApexOptions options,
    TextDrawer labeller,
  ) {
    final double labelY = layout.plotRect.bottom + 8;

    if (options.xAxisType == ApexXAxisType.category) {
      final cats = layout.xCategories;
      final n = layout.pointCount;
      // Bars label the center of each category band; line/area label the
      // point position (edge-to-edge).
      final bool banded = options.type == ApexChartType.bar;

      // Rotation and label-thinning are decided once in CartesianLayout
      // (resolveCategoryLabels), which also sizes the bottom gutter around
      // the same answer — recomputing it here could disagree with how much
      // room was actually reserved.
      final bool rotate = layout.xLabelsRotated;
      final int step = layout.xLabelStep;
      const double rotation = -0.7853981633974483; // -45°

      for (int i = 0; i < n; i++) {
        // Thin out when even rotating doesn't leave enough room per label —
        // better to show fewer, readable labels than every one overlapping
        // its neighbor (same trade-off ApexCharts/Highcharts make on dense
        // category axes).
        if (i % step != 0) continue;
        final label = i < cats.length ? cats[i] : (i + 1).toString();
        final x = banded ? layout.xBandCenter(i) : layout.xCategoryToPixel(i);
        // When zoomed, categories outside the visible window map outside the
        // plot; ApexCharts only draws ticks within the grid, so skip those.
        if (x < layout.plotRect.left - 1 || x > layout.plotRect.right + 1) {
          continue;
        }
        if (rotate) {
          labeller.draw(
            canvas,
            label,
            Offset(x, labelY + 2),
            anchor: TextAnchor.end,
            rotation: rotation,
          );
        } else {
          labeller.draw(
            canvas,
            label,
            Offset(x, labelY),
            anchor: TextAnchor.middle,
          );
        }
      }
    } else if (options.xAxisType == ApexXAxisType.datetime) {
      // Datetime: calendar-aligned ticks (TimeScale), each carrying a label
      // whose format depends on the visible span (years / "MMM 'yy" / "dd MMM"
      // / "HH:mm"). This is what makes a multi-year window show months/years
      // instead of repeated day-of-month labels.
      final ticks = TimeScale.ticks(
        layout.xViewMin,
        layout.xViewMax,
        tickAmount: options.tickAmount,
        gridWidth: layout.plotRect.width,
      );
      for (final tick in ticks) {
        final x = layout.xValueToPixel(tick.ms);
        if (x < layout.plotRect.left - 1 || x > layout.plotRect.right + 1) {
          continue;
        }
        labeller.draw(
          canvas,
          tick.label,
          Offset(x, labelY),
          anchor: TextAnchor.middle,
        );
      }
    } else {
      // numeric: "nice" round-number ticks (same algorithm the y-axis
      // already uses), instead of naive evenly-spaced fractions of the raw
      // data range — an axis spanning 0..23 used to print "3.83, 7.67,
      // 11.50..." instead of "0, 5, 10, 15, 20". Ticks that fall outside the
      // actual view (nice bounds can slightly overshoot the raw data) are
      // clipped below, same as the datetime tick loop.
      final ticks = numericXTicks(
        xMin: layout.xViewMin,
        xMax: layout.xViewMax,
        plotWidth: layout.plotRect.width,
        tickAmount: options.tickAmount,
      );
      for (final tick in ticks) {
        final x = layout.xValueToPixel(tick.toDouble());
        if (x < layout.plotRect.left - 1 || x > layout.plotRect.right + 1) {
          continue;
        }
        labeller.draw(
          canvas,
          FormatValue.formatted(tick, options.xLabelFormat),
          Offset(x, labelY),
          anchor: TextAnchor.middle,
        );
      }
    }
  }

  /// "Nice" round-number tick values for a numeric x-axis spanning
  /// [xMin]..[xMax] — pure (no Canvas), so it's directly testable. Mirrors
  /// the y-axis's own `NiceScale.niceScale` call in `CartesianLayout`.
  /// Honors an explicit [tickAmount] (`xaxis.tickAmount`) as the upper bound
  /// fed into the nice-scale algorithm; otherwise derives one from
  /// [plotWidth] the same way the y-axis derives its bound from height.
  static List<num> numericXTicks({
    required double xMin,
    required double xMax,
    required double plotWidth,
    int? tickAmount,
  }) {
    final double autoMaxTicks = math.max((plotWidth - 40) / 70, 2);
    final double maxTicks = tickAmount?.toDouble() ?? autoMaxTicks;
    return NiceScale.niceScale(xMin, xMax, maxTicks: maxTicks).result;
  }

  static String _fmtNum(num v) {
    if (v == v.truncate()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}
