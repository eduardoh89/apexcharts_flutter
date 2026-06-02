import 'dart:math' as math;
import 'dart:ui';

import '../options/apex_options.dart';
import '../svg/text_drawer.dart';
import '../utils/range.dart';

/// An x-axis viewport in *domain units*, used for zoom/pan. For category and
/// numeric/scatter charts the domain unit is the data-point **index**
/// (0..pointCount-1); for datetime it is the epoch-ms x value. `null` means
/// "full extent" (no zoom).
class XWindow {
  const XWindow(this.min, this.max);
  final double min;
  final double max;

  double get span => max - min;

  XWindow clampTo(double domainMin, double domainMax) {
    // A one-sided initial window (e.g. only `xaxis.min`) arrives with the open
    // edge as ±infinity; resolve those to the domain bounds first so the
    // edge-shifting below doesn't blow up to ±infinity (ApexCharts treats a
    // missing min/max as the data extent).
    var lo = min.isFinite ? min : domainMin;
    var hi = max.isFinite ? max : domainMax;
    // Keep a minimum 1% span so the view can't collapse.
    final minSpan = (domainMax - domainMin) * 0.01;
    if (hi - lo < minSpan) {
      final mid = (lo + hi) / 2;
      lo = mid - minSpan / 2;
      hi = mid + minSpan / 2;
    }
    if (lo < domainMin) {
      hi += domainMin - lo;
      lo = domainMin;
    }
    if (hi > domainMax) {
      lo -= hi - domainMax;
      hi = domainMax;
    }
    return XWindow(lo.clamp(domainMin, domainMax), hi.clamp(domainMin, domainMax));
  }

  @override
  bool operator ==(Object other) =>
      other is XWindow && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);
}

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
    required this.xDomainMin,
    required this.xDomainMax,
    required this.xViewMin,
    required this.xViewMax,
  });

  /// Full x-domain extent in domain units (index for category/numeric, epoch
  /// ms for datetime). Zoom/pan windows are expressed against this.
  final double xDomainMin;
  final double xDomainMax;

  /// Currently visible x-domain window (defaults to the full extent).
  final double xViewMin;
  final double xViewMax;

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
    XWindow? xWindow,
  }) {
    // The x-domain is index-based for category/numeric/scatter and epoch-ms for
    // datetime. The visible window narrows it for zoom/pan.
    int maxPoints = 0;
    for (final s in options.series) {
      maxPoints = math.max(maxPoints, s.points.length);
    }

    double domainMin;
    double domainMax;
    // datetime and numeric x-axes map by the real x value (epoch ms or a plain
    // number, e.g. scatter/bubble); category maps by point index.
    if (options.xAxisType == ApexXAxisType.datetime ||
        options.xAxisType == ApexXAxisType.numeric) {
      double lo = double.infinity, hi = -double.infinity;
      for (final s in options.series) {
        for (final p in s.points) {
          final x = p.x ?? 0;
          lo = math.min(lo, x);
          hi = math.max(hi, x);
        }
      }
      if (!lo.isFinite) {
        lo = 0;
        hi = 1;
      }
      // Honor explicit xaxis.min/max (the demo's [0, 100] bounds).
      domainMin = options.xMin ?? lo;
      domainMax = options.xMax ?? hi;
    } else {
      domainMin = 0;
      domainMax = (maxPoints <= 1 ? 1 : maxPoints - 1).toDouble();
    }

    final XWindow view =
        (xWindow ?? XWindow(domainMin, domainMax)).clampTo(domainMin, domainMax);

    // Determine y extent across all series, but only over the VISIBLE x-window
    // so zooming in rescales the y-axis like ApexCharts does.
    double yLo = double.infinity;
    double yHi = -double.infinity;
    for (final s in options.series) {
      for (int i = 0; i < s.points.length; i++) {
        final p = s.points[i];
        if (p.isNull) continue;
        final double xDomain = (options.xAxisType == ApexXAxisType.datetime ||
                options.xAxisType == ApexXAxisType.numeric)
            ? (p.x ?? 0)
            : i.toDouble();
        if (xDomain < view.min - 1e-9 || xDomain > view.max + 1e-9) continue;
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

    // Reserve extra space for axis titles when present (ApexCharts adds ~18px
    // beyond the tick labels for each axis title).
    final double yTitlePad = options.yTitle.hasText ? 18 : 0;
    final double xTitlePad = options.xTitle.hasText ? 18 : 0;

    final plotRect = Rect.fromLTRB(
      leftGutter + legendLeft + yTitlePad,
      _topPadding + legendTop,
      size.width - _rightPadding - legendRight,
      size.height - _bottomGutter - legendBottom - xTitlePad,
    );

    return CartesianLayout._(
      plotRect: plotRect,
      yTicks: scale.result,
      yMin: scale.niceMin.toDouble(),
      yMax: scale.niceMax.toDouble(),
      pointCount: maxPoints,
      xCategories: options.categories,
      xAxisType: options.xAxisType,
      xNumericMin: domainMin,
      xNumericMax: domainMax,
      xDomainMin: domainMin,
      xDomainMax: domainMax,
      xViewMin: view.min,
      xViewMax: view.max,
    );
  }

  /// Interpolate between two layouts for a zoom transition.
  ///
  /// This is the apex_dart equivalent of ApexCharts' `Animations.morphSVG`
  /// (`el.plot(pathFrom).animate(speed).plot(pathTo)`): rather than recomputing
  /// `niceScale` every frame from the interpolated x-window — which makes the
  /// y-axis snap in discrete "nice number" steps while x slides smoothly — we
  /// compute the *start* and *target* layouts once and lerp their numeric
  /// fields. Because `yToPixel`/`xValueToPixel` read these lerped bounds, every
  /// data point's pixel position moves continuously on **both** axes at once,
  /// exactly like ApexCharts morphing the series paths.
  static CartesianLayout lerp(CartesianLayout a, CartesianLayout b, double t) {
    double mix(double x, double y) => x + (y - x) * t;

    final yMin = mix(a.yMin, b.yMin);
    final yMax = mix(a.yMax, b.yMax);

    // Evenly spaced transitional ticks over the interpolated y-range, keeping
    // the target tick count so it converges exactly to the target's nice ticks
    // at t == 1 (target ticks are themselves evenly spaced).
    final int tickCount = b.yTicks.length >= 2 ? b.yTicks.length : 2;
    final ticks = <num>[];
    final double step = (yMax - yMin) / (tickCount - 1);
    for (int i = 0; i < tickCount; i++) {
      ticks.add(yMin + step * i);
    }

    return CartesianLayout._(
      plotRect: Rect.lerp(a.plotRect, b.plotRect, t)!,
      yTicks: ticks,
      yMin: yMin,
      yMax: yMax,
      pointCount: b.pointCount,
      xCategories: b.xCategories,
      xAxisType: b.xAxisType,
      xNumericMin: b.xNumericMin,
      xNumericMax: b.xNumericMax,
      xDomainMin: b.xDomainMin,
      xDomainMax: b.xDomainMax,
      xViewMin: mix(a.xViewMin, b.xViewMin),
      xViewMax: mix(a.xViewMax, b.xViewMax),
    );
  }

  /// Whether the chart is zoomed in (view narrower than full domain).
  bool get isZoomed =>
      xViewMin > xDomainMin + 1e-9 || xViewMax < xDomainMax - 1e-9;

  /// Map a y data value to a pixel y (inverted: high values near the top).
  double yToPixel(num value) {
    final t = (value - yMin) / (yMax - yMin == 0 ? 1 : yMax - yMin);
    return plotRect.bottom - t * plotRect.height;
  }

  /// Map a category/data-point index to a pixel x, honoring the zoom window.
  ///
  /// Index 0 sits at the left edge and the last index at the right edge when
  /// unzoomed; when zoomed the visible window [xViewMin, xViewMax] (in index
  /// units) is stretched across the full plot width.
  double xCategoryToPixel(int index) {
    if (pointCount <= 1) return plotRect.center.dx;
    final span = xViewMax - xViewMin;
    final t = span == 0 ? 0.0 : (index - xViewMin) / span;
    return plotRect.left + t * plotRect.width;
  }

  /// Map a numeric/datetime x value to a pixel x, honoring the zoom window.
  double xValueToPixel(double value) {
    final span = xViewMax - xViewMin;
    final t = span == 0 ? 0.0 : (value - xViewMin) / span;
    return plotRect.left + t * plotRect.width;
  }

  /// Inverse of [xCategoryToPixel]/[xValueToPixel]: pixel x → x-domain value.
  double pixelToXDomain(double px) {
    final t = (px - plotRect.left) / (plotRect.width == 0 ? 1 : plotRect.width);
    return xViewMin + t * (xViewMax - xViewMin);
  }

  /// Center pixel x for a category band (used by bar charts), honoring zoom.
  ///
  /// Bars use a *band* model: each index occupies one slot of width
  /// [bandWidth]; index `j`'s center sits half a band into its slot. The
  /// visible window covers `viewSpan + 1` bands stretched across the plot.
  double xBandCenter(int index) {
    if (pointCount <= 0) return plotRect.center.dx;
    return plotRect.left + (index - xViewMin + 0.5) * bandWidth;
  }

  double get bandWidth {
    if (pointCount <= 0) return plotRect.width;
    final visibleBands = (xViewMax - xViewMin) + 1;
    return plotRect.width / (visibleBands <= 0 ? 1 : visibleBands);
  }

  static String _fmt(num v) {
    if (v == v.truncate()) return v.toInt().toString();
    return v.toString();
  }
}
