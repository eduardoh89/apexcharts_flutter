import 'dart:math' as math;
import 'dart:ui';

import '../options/apex_options.dart';
import '../svg/text_drawer.dart';
import '../utils/range.dart';

/// Computes the cartesian plot geometry for line/area/bar/scatter charts:
/// the inner plot rect (after reserving space for axis labels), the y-axis
/// tick values, and value→pixel mapping functions.
///
/// This consolidates the layout math that ApexCharts spreads across
/// `Dimensions`, `Scales`, `Axes` and the grid renderer.
class CartesianLayout {
  CartesianLayout._({
    required this.plotRect,
    required this.yTicks,
    required this.yMin,
    required this.yMax,
    required this.pointCount,
    required this.xCategories,
    required this.xAxisType,
    required this.xNumericMin,
    required this.xNumericMax,
  });

  /// The drawable plotting area (excludes axis gutters).
  final Rect plotRect;

  /// Y-axis tick values from bottom to top.
  final List<num> yTicks;
  final double yMin;
  final double yMax;

  /// Number of x slots (categories or data points).
  final int pointCount;
  final List<String> xCategories;
  final ApexXAxisType xAxisType;

  /// For datetime/numeric x-axes, the value extent.
  final double xNumericMin;
  final double xNumericMax;

  /// Default axis gutters (px) — ApexCharts reserves ~similar space.
  static const double _leftGutter = 50;
  static const double _bottomGutter = 34;
  static const double _topPadding = 10;
  static const double _rightPadding = 12;

  /// Build the layout for [options] within a canvas of [size].
  ///
  /// [legendBottom], [legendTop], [legendLeft], [legendRight] are pixel insets
  /// already reserved for the legend so the plot area does not overlap it.
  factory CartesianLayout.compute(
    ApexOptions options,
    Size size, {
    double legendBottom = 0,
    double legendTop = 0,
    double legendLeft = 0,
    double legendRight = 0,
  }) {
    // Determine y extent across all series.
    double yLo = double.infinity;
    double yHi = -double.infinity;
    int maxPoints = 0;
    for (final s in options.series) {
      maxPoints = math.max(maxPoints, s.points.length);
      for (final p in s.points) {
        yLo = math.min(yLo, p.y);
        yHi = math.max(yHi, p.y);
      }
    }
    if (!yLo.isFinite || !yHi.isFinite) {
      yLo = 0;
      yHi = 1;
    }

    // For bar charts ApexCharts always includes the zero baseline.
    if (options.type == ApexChartType.bar) {
      yLo = math.min(yLo, 0);
      yHi = math.max(yHi, 0);
    }

    // maxTicks from height, matching Scales.niceScale: (svgHeight-100)/15.
    final double maxTicks = math.max((size.height - 100) / 15, 2);
    final scale = NiceScale.niceScale(yLo, yHi, maxTicks: maxTicks);

    // Reserve gutter width based on the widest y label.
    final labeller = TextDrawer(fontFamily: options.fontFamily);
    double widestLabel = 0;
    for (final t in scale.result) {
      widestLabel = math.max(widestLabel, labeller.measure(_fmt(t)).width);
    }
    final double leftGutter = math.max(_leftGutter, widestLabel + 16);

    final plotRect = Rect.fromLTRB(
      leftGutter + legendLeft,
      _topPadding + legendTop,
      size.width - _rightPadding - legendRight,
      size.height - _bottomGutter - legendBottom,
    );

    // X extent for datetime/numeric.
    double xLo = 0;
    double xHi = 0;
    if (options.xAxisType != ApexXAxisType.category) {
      xLo = double.infinity;
      xHi = -double.infinity;
      for (final s in options.series) {
        for (final p in s.points) {
          final x = p.x ?? 0;
          xLo = math.min(xLo, x);
          xHi = math.max(xHi, x);
        }
      }
      if (!xLo.isFinite) {
        xLo = 0;
        xHi = 1;
      }
    }

    return CartesianLayout._(
      plotRect: plotRect,
      yTicks: scale.result,
      yMin: scale.niceMin.toDouble(),
      yMax: scale.niceMax.toDouble(),
      pointCount: maxPoints,
      xCategories: options.categories,
      xAxisType: options.xAxisType,
      xNumericMin: xLo,
      xNumericMax: xHi,
    );
  }

  /// Map a y data value to a pixel y (inverted: high values near the top).
  double yToPixel(num value) {
    final t = (value - yMin) / (yMax - yMin == 0 ? 1 : yMax - yMin);
    return plotRect.bottom - t * plotRect.height;
  }

  /// Map a category index to a pixel x.
  ///
  /// ApexCharts places category-based line/area points spread across the full
  /// plot width: index 0 at the left edge, last index at the right edge.
  double xCategoryToPixel(int index) {
    if (pointCount <= 1) return plotRect.center.dx;
    final t = index / (pointCount - 1);
    return plotRect.left + t * plotRect.width;
  }

  /// Map a numeric/datetime x value to a pixel x.
  double xValueToPixel(double value) {
    final range = xNumericMax - xNumericMin;
    final t = range == 0 ? 0.0 : (value - xNumericMin) / range;
    return plotRect.left + t * plotRect.width;
  }

  /// Center pixel x for a category band (used by bar charts).
  double xBandCenter(int index) {
    if (pointCount <= 0) return plotRect.center.dx;
    final bandWidth = plotRect.width / pointCount;
    return plotRect.left + bandWidth * (index + 0.5);
  }

  double get bandWidth =>
      pointCount <= 0 ? plotRect.width : plotRect.width / pointCount;

  static String _fmt(num v) {
    if (v == v.truncate()) return v.toInt().toString();
    return v.toString();
  }
}
