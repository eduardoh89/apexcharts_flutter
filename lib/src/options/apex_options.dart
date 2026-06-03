import 'dart:ui';

import '../utils/apex_color.dart';

/// Chart type, mirroring ApexCharts `chart.type`.
enum ApexChartType {
  line,
  area,
  bar,
  pie,
  donut,
  scatter,
  bubble,
  rangeBar,
  candlestick,
  radar,
  radialBar,
  heatmap,
  treemap;

  static ApexChartType parse(String? v) {
    switch (v) {
      case 'area':
        return ApexChartType.area;
      case 'bar':
        return ApexChartType.bar;
      case 'rangeBar':
        return ApexChartType.rangeBar;
      case 'candlestick':
        return ApexChartType.candlestick;
      case 'treemap':
        return ApexChartType.treemap;
      case 'radar':
        return ApexChartType.radar;
      case 'pie':
        return ApexChartType.pie;
      case 'donut':
        return ApexChartType.donut;
      case 'scatter':
        return ApexChartType.scatter;
      case 'bubble':
        return ApexChartType.bubble;
      case 'radialBar':
        return ApexChartType.radialBar;
      case 'heatmap':
        return ApexChartType.heatmap;
      case 'line':
      default:
        return ApexChartType.line;
    }
  }

  bool get isCartesian =>
      this == line ||
      this == area ||
      this == bar ||
      this == scatter ||
      this == bubble ||
      this == rangeBar ||
      this == candlestick;
  bool get isRadial => this == pie || this == donut || this == radialBar;
}

/// Stroke curve interpolation, mirroring ApexCharts `stroke.curve`.
enum ApexCurve {
  straight,
  smooth,
  stepline;

  static ApexCurve parse(Object? v) {
    if (v == 'smooth') return ApexCurve.smooth;
    if (v == 'stepline') return ApexCurve.stepline;
    return ApexCurve.straight;
  }
}

/// X-axis kind, mirroring ApexCharts `xaxis.type`.
enum ApexXAxisType { category, datetime, numeric }

/// One data series. For cartesian charts [points] carry x/y; for radial charts
/// only the y values are used (with [PieOptions.labels]).
class ApexSeries {
  ApexSeries({required this.name, required this.points, this.color});

  final String name;
  final List<ApexPoint> points;

  /// Optional per-series color override (else taken from the palette).
  final Color? color;

  List<double> get yValues => points.map((p) => p.y).toList();
}

/// A single datum. [x] is null for category charts where the index is implied.
/// [isNull] marks a missing value (ApexCharts `null` data point) so line/area
/// renderers break the path into segments instead of drawing through it.
class ApexPoint {
  const ApexPoint({
    this.x,
    required this.y,
    this.yHigh,
    this.z,
    this.ohlc,
    this.label,
    this.isNull = false,
  });
  final double? x;

  /// For plain points the value; for range/timeline points the **start** of the
  /// range (low), with [yHigh] the end (high).
  final double y;

  /// Range end for rangeBar/timeline points (`y: [start, end]`). Null for
  /// non-range points.
  final double? yHigh;

  /// Third dimension for bubble charts (`[x, y, z]` / `{x, y, z}`); the bubble
  /// radius is derived from this. Null for non-bubble points.
  final double? z;

  /// Open-high-low-close values for candlestick points (`y: [o, h, l, c]`).
  /// Null for non-candlestick points.
  final List<double>? ohlc;

  /// Category/row label carried on the point (timeline `{ x: 'Label', y: [..] }`).
  final String? label;

  final bool isNull;

  bool get isRange => yHigh != null;
  bool get isOhlc => ohlc != null;
}

/// The default ApexCharts color palette ("palette1").
const List<String> kApexDefaultPalette = [
  '#008FFB',
  '#00E396',
  '#FEB019',
  '#FF4560',
  '#775DD0',
  '#3F51B5',
  '#03A9F4',
  '#4CAF50',
  '#F9CE1D',
  '#FF9800',
];

/// Legend placement.
enum ApexLegendPosition { top, right, bottom, left, none }

/// Legend configuration (`legend`), mirroring the subset of ApexCharts'
/// `legend` options apex_dart honors: placement and single-series visibility.
class ApexLegend {
  const ApexLegend({
    this.position = ApexLegendPosition.bottom,
    this.showForSingleSeries = false,
  });
  final ApexLegendPosition position;

  /// `legend.showForSingleSeries` — when false (ApexCharts default) an axis
  /// chart with a single series hides its legend.
  final bool showForSingleSeries;

  static ApexLegend parse(Map<String, dynamic>? json) {
    if (json == null) return const ApexLegend();
    final show = json['show'];
    if (show == false) {
      return const ApexLegend(position: ApexLegendPosition.none);
    }
    final single = json['showForSingleSeries'] as bool? ?? false;
    switch (json['position']) {
      case 'top':
        return ApexLegend(
            position: ApexLegendPosition.top, showForSingleSeries: single);
      case 'right':
        return ApexLegend(
            position: ApexLegendPosition.right, showForSingleSeries: single);
      case 'left':
        return ApexLegend(
            position: ApexLegendPosition.left, showForSingleSeries: single);
      case 'bottom':
        return ApexLegend(
            position: ApexLegendPosition.bottom, showForSingleSeries: single);
      default:
        return ApexLegend(showForSingleSeries: single);
    }
  }
}

/// Bar-specific plot options.
class ApexBarOptions {
  const ApexBarOptions({
    this.horizontal = false,
    this.columnWidthFraction = 0.7,
    this.borderRadius = 0,
  });

  final bool horizontal;

  /// Fraction (0..1) of the category slot occupied by the bar group. For
  /// vertical bars this comes from `bar.columnWidth`; for horizontal/range bars
  /// from `bar.barHeight` (ApexCharts uses the orientation-appropriate one).
  final double columnWidthFraction;
  final double borderRadius;

  static ApexBarOptions parse(Map<String, dynamic>? bar) {
    if (bar == null) return const ApexBarOptions();
    final horizontal = bar['horizontal'] as bool? ?? false;
    final thickness = horizontal
        ? (_parsePercent(bar['barHeight']) ?? _parsePercent(bar['columnWidth']))
        : (_parsePercent(bar['columnWidth']) ??
            _parsePercent(bar['barHeight']));
    return ApexBarOptions(
      horizontal: horizontal,
      columnWidthFraction: thickness ?? 0.7,
      borderRadius: (bar['borderRadius'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Pie/donut-specific plot options.
class ApexPieOptions {
  const ApexPieOptions({this.donutSizeFraction = 0.65});

  /// Inner-radius fraction for donuts (0 = full pie).
  final double donutSizeFraction;

  static ApexPieOptions parse(Map<String, dynamic>? pie) {
    if (pie == null) return const ApexPieOptions();
    final donut = pie['donut'] as Map<String, dynamic>?;
    return ApexPieOptions(
      donutSizeFraction: _parsePercent(donut?['size']) ?? 0.65,
    );
  }
}

/// RadialBar (circular gauge) plot options, ported from ApexCharts
/// `settings/Options.js` `plotOptions.radialBar` (startAngle:0, endAngle:360,
/// hollow.size:'50%', track.show:true, track.margin:5, track.strokeWidth:'97%',
/// dataLabels.value.show:true).
class ApexRadialBarOptions {
  const ApexRadialBarOptions({
    this.startAngle = 0,
    this.endAngle = 360,
    this.hollowSizeFraction = 0.5,
    this.trackShow = true,
    this.trackMargin = 5,
    this.trackStrokeWidthFraction = 0.97,
    this.dataLabelsShow = true,
  });

  final num startAngle;
  final num endAngle;

  /// `hollow.size` as a 0..1 fraction of the outer radius.
  final double hollowSizeFraction;
  final bool trackShow;
  final double trackMargin;
  final double trackStrokeWidthFraction;
  final bool dataLabelsShow;

  static ApexRadialBarOptions parse(Map<String, dynamic>? r) {
    if (r == null) return const ApexRadialBarOptions();
    final hollow = r['hollow'] as Map<String, dynamic>?;
    final track = r['track'] as Map<String, dynamic>?;
    final dataLabels = r['dataLabels'] as Map<String, dynamic>?;
    final value = dataLabels?['value'] as Map<String, dynamic>?;
    return ApexRadialBarOptions(
      startAngle: (r['startAngle'] as num?) ?? 0,
      endAngle: (r['endAngle'] as num?) ?? 360,
      hollowSizeFraction: _parsePercent(hollow?['size']) ?? 0.5,
      trackShow: track?['show'] as bool? ?? true,
      trackMargin: (track?['margin'] as num?)?.toDouble() ?? 5,
      trackStrokeWidthFraction: _parsePercent(track?['strokeWidth']) ?? 0.97,
      dataLabelsShow: value?['show'] as bool? ?? true,
    );
  }
}

/// Candlestick plot options, ported from ApexCharts `settings/Options.js`
/// `plotOptions.candlestick` (colors.upward '#00B746', downward '#EF403C').
class ApexCandlestickOptions {
  const ApexCandlestickOptions({this.upwardColor, this.downwardColor});

  final Color? upwardColor;
  final Color? downwardColor;

  static ApexCandlestickOptions parse(Map<String, dynamic>? c) {
    if (c == null) return const ApexCandlestickOptions();
    final colors = c['colors'] as Map<String, dynamic>?;
    Color? col(Object? v) => v is String ? ApexColor.fromHex(v) : null;
    return ApexCandlestickOptions(
      upwardColor: col(colors?['upward']),
      downwardColor: col(colors?['downward']),
    );
  }
}

/// Treemap plot options, ported from ApexCharts `settings/Options.js`
/// `plotOptions.treemap` (enableShades:true, shadeIntensity:0.5,
/// distributed:false, borderRadius:4).
class ApexTreemapOptions {
  const ApexTreemapOptions({
    this.enableShades = true,
    this.shadeIntensity = 0.5,
    this.distributed = false,
    this.borderRadius = 4,
  });

  final bool enableShades;
  final double shadeIntensity;
  final bool distributed;
  final double borderRadius;

  static ApexTreemapOptions parse(Map<String, dynamic>? t) {
    if (t == null) return const ApexTreemapOptions();
    return ApexTreemapOptions(
      enableShades: t['enableShades'] as bool? ?? true,
      shadeIntensity: (t['shadeIntensity'] as num?)?.toDouble() ?? 0.5,
      distributed: t['distributed'] as bool? ?? false,
      borderRadius: (t['borderRadius'] as num?)?.toDouble() ?? 4,
    );
  }
}

/// HeatMap plot options, ported from ApexCharts `settings/Options.js`
/// `plotOptions.heatmap` (radius:2, enableShades:true, shadeIntensity:0.5).
class ApexHeatmapOptions {
  const ApexHeatmapOptions({
    this.radius = 2,
    this.enableShades = true,
    this.shadeIntensity = 0.5,
  });

  final double radius;
  final bool enableShades;
  final double shadeIntensity;

  static ApexHeatmapOptions parse(Map<String, dynamic>? h) {
    if (h == null) return const ApexHeatmapOptions();
    return ApexHeatmapOptions(
      radius: (h['radius'] as num?)?.toDouble() ?? 2,
      enableShades: h['enableShades'] as bool? ?? true,
      shadeIntensity: (h['shadeIntensity'] as num?)?.toDouble() ?? 0.5,
    );
  }
}

/// Bubble-specific plot options, ported from ApexCharts
/// `settings/Options.js` `plotOptions.bubble` (zScaling:true, min/max radius
/// undefined by default).
class ApexBubbleOptions {
  const ApexBubbleOptions({
    this.zScaling = true,
    this.minBubbleRadius,
    this.maxBubbleRadius,
  });

  /// Whether the z value is scaled by the global z-ratio (`bubble.zScaling`).
  final bool zScaling;
  final double? minBubbleRadius;
  final double? maxBubbleRadius;

  static ApexBubbleOptions parse(Map<String, dynamic>? bubble) {
    if (bubble == null) return const ApexBubbleOptions();
    return ApexBubbleOptions(
      zScaling: bubble['zScaling'] as bool? ?? true,
      minBubbleRadius: (bubble['minBubbleRadius'] as num?)?.toDouble(),
      maxBubbleRadius: (bubble['maxBubbleRadius'] as num?)?.toDouble(),
    );
  }
}

/// Point-marker configuration for line/area/scatter, ported from ApexCharts
/// `markers`. ApexCharts defaults `size: 0` for line/area (markers hidden until
/// hover) and `size: 6` for scatter.
class ApexMarkers {
  const ApexMarkers({
    required this.size,
    this.strokeWidth = 2,
    this.strokeColor = const Color(0xFFFFFFFF),
    this.hoverSize = 6,
  });

  /// Base marker radius in px. 0 hides the static marker.
  final double size;
  final double strokeWidth;
  final Color strokeColor;

  /// Radius used when a point is highlighted on hover (ApexCharts
  /// `markers.hover.size`, default ~ size+3, min 6 for line/area).
  final double hoverSize;

  static ApexMarkers parse(Map<String, dynamic>? m, ApexChartType type) {
    final double defaultSize = type == ApexChartType.scatter ? 6 : 0;
    if (m == null) return ApexMarkers(size: defaultSize);
    final size = _firstNum(m['size'])?.toDouble() ?? defaultSize;
    final hover = m['hover'] as Map<String, dynamic>?;
    final hoverSize =
        _firstNum(hover?['size'])?.toDouble() ?? (size > 0 ? size + 3 : 6);
    return ApexMarkers(
      size: size,
      strokeWidth: _firstNum(m['strokeWidth'])?.toDouble() ?? 2,
      strokeColor: m['strokeColors'] is String
          ? ApexColor.fromHex(m['strokeColors'] as String)
          : const Color(0xFFFFFFFF),
      hoverSize: hoverSize,
    );
  }
}

/// A value formatter: prefix/suffix wrapping plus fixed decimal places,
/// covering the common `tooltip.y.formatter` / `yaxis.labels.formatter` cases
/// (currency, %, units) without requiring a Dart callback in JSON.
class ApexValueFormat {
  const ApexValueFormat({
    this.prefix = '',
    this.suffix = '',
    this.decimals,
  });

  final String prefix;
  final String suffix;

  /// Fixed decimal places; null = ApexCharts default (whole numbers bare,
  /// otherwise trimmed).
  final int? decimals;

  bool get isIdentity => prefix.isEmpty && suffix.isEmpty && decimals == null;

  static ApexValueFormat parse(Map<String, dynamic>? json) {
    if (json == null) return const ApexValueFormat();
    return ApexValueFormat(
      prefix: json['prefix'] as String? ?? '',
      suffix: json['suffix'] as String? ?? '',
      decimals: (json['decimals'] as num?)?.toInt(),
    );
  }
}

/// Mount-animation configuration (`chart.animations`). ApexCharts enables a
/// ~800ms ease-out entrance animation by default.
class ApexAnimations {
  const ApexAnimations({this.enabled = true, this.speedMs = 800});
  final bool enabled;
  final int speedMs;

  static ApexAnimations parse(Map<String, dynamic>? a) {
    if (a == null) return const ApexAnimations();
    return ApexAnimations(
      enabled: a['enabled'] as bool? ?? true,
      speedMs: (a['speed'] as num?)?.toInt() ?? 800,
    );
  }
}

/// Zoom / pan configuration, ported from ApexCharts `chart.zoom` +
/// `chart.toolbar`. ApexCharts enables x-zoom by default for line/area charts.
class ApexZoom {
  const ApexZoom({
    this.enabled = false,
    this.showToolbar = true,
    this.autoScaleYaxis = false,
  });

  /// Whether drag-select + wheel zoom and pan are active.
  final bool enabled;

  /// Whether to show the reset/zoom toolbar buttons.
  final bool showToolbar;

  /// Whether the y-axis rescales to the zoomed window (`zoom.autoScaleYaxis`).
  final bool autoScaleYaxis;

  static ApexZoom parse(
    Map<String, dynamic>? zoom,
    Map<String, dynamic>? toolbar,
    ApexChartType type,
  ) {
    // ApexCharts default: zoom enabled for line/area/scatter, off for bar/pie.
    final bool defaultEnabled =
        type == ApexChartType.line || type == ApexChartType.area;
    final enabled = zoom?['enabled'] as bool? ?? defaultEnabled;
    final showToolbar = toolbar?['show'] as bool? ?? true;
    final autoScale = zoom?['autoScaleYaxis'] as bool? ?? false;
    return ApexZoom(
      enabled: enabled,
      showToolbar: showToolbar,
      autoScaleYaxis: autoScale,
    );
  }
}

/// Gradient fill config for area charts (`fill.gradient`).
class ApexGradientFill {
  const ApexGradientFill({
    this.enabled = false,
    this.opacityFrom = 0.65,
    this.opacityTo = 0.05,
    this.stops = const [0, 100],
    this.shade = 'dark',
    this.shadeIntensity = 0.5,
    this.inverseColors = true,
  });

  /// Whether a vertical gradient fill is used (fill.type == 'gradient').
  final bool enabled;
  final double opacityFrom;
  final double opacityTo;

  /// Gradient color stops as percentages [start, end].
  final List<double> stops;

  /// `fill.gradient.shade` — 'dark' shades the second color toward black,
  /// 'light' toward white (ApexCharts Fill.js).
  final String shade;

  /// `fill.gradient.shadeIntensity` — how far the second color is shaded.
  final double shadeIntensity;

  /// `fill.gradient.inverseColors` — swap the from/to colors (default true), so
  /// the *shaded* color sits at the top of the area and the base color at the
  /// bottom.
  final bool inverseColors;

  static ApexGradientFill parse(
      Map<String, dynamic>? fill, ApexChartType type) {
    // ApexCharts' per-chart Defaults override the global fill gradient. For
    // area charts (`Defaults.area()`), the fill gradient defaults to
    // shade:'light', inverseColors:false, opacityFrom:0.65, opacityTo:0.5 — so
    // the bottom of the area fades toward WHITE (the pale band in the demo),
    // not toward black like the global default. Line/scatter keep the global
    // shade:'dark' default.
    final bool isArea = type == ApexChartType.area;
    final double defOpacityFrom = isArea ? 0.65 : 0.65;
    final double defOpacityTo = isArea ? 0.5 : 0.05;
    final String defShade = isArea ? 'light' : 'dark';
    final bool defInverse = isArea ? false : true;

    if (fill == null) {
      return ApexGradientFill(
        enabled: true,
        opacityFrom: defOpacityFrom,
        opacityTo: defOpacityTo,
        shade: defShade,
        inverseColors: defInverse,
      );
    }
    final isGradient = fill['type'] == 'gradient';
    final g = fill['gradient'] as Map<String, dynamic>?;
    return ApexGradientFill(
      enabled: isGradient || g != null,
      opacityFrom: (g?['opacityFrom'] as num?)?.toDouble() ?? defOpacityFrom,
      opacityTo: (g?['opacityTo'] as num?)?.toDouble() ?? defOpacityTo,
      stops:
          (g?['stops'] as List?)?.map((e) => (e as num).toDouble()).toList() ??
              const [0, 100],
      shade: g?['shade'] as String? ?? defShade,
      shadeIntensity: (g?['shadeIntensity'] as num?)?.toDouble() ?? 0.5,
      inverseColors: g?['inverseColors'] as bool? ?? defInverse,
    );
  }
}

/// A horizontal (y) or vertical (x) annotation line with an optional label,
/// ported from ApexCharts `annotations.yaxis[]` / `annotations.xaxis[]`.
class ApexAnnotation {
  const ApexAnnotation({
    required this.value,
    required this.isXAxis,
    this.borderColor = const Color(0xFF999999),
    this.labelText,
    this.labelColor = const Color(0xFFFFFFFF),
    this.labelBg = const Color(0xFF775DD0),
  });

  /// The axis value at which to draw the line (y-value, or x epoch-ms).
  final double value;

  /// True for a vertical line at an x value; false for a horizontal y line.
  final bool isXAxis;

  final Color borderColor;
  final String? labelText;
  final Color labelColor;
  final Color labelBg;

  static List<ApexAnnotation> parseAll(Map<String, dynamic>? annotations) {
    if (annotations == null) return const [];
    final out = <ApexAnnotation>[];
    for (final entry in (annotations['yaxis'] as List? ?? const [])) {
      final m = entry as Map<String, dynamic>;
      out.add(_one(m, isXAxis: false, key: 'y'));
    }
    for (final entry in (annotations['xaxis'] as List? ?? const [])) {
      final m = entry as Map<String, dynamic>;
      out.add(_one(m, isXAxis: true, key: 'x'));
    }
    return out;
  }

  static ApexAnnotation _one(
    Map<String, dynamic> m, {
    required bool isXAxis,
    required String key,
  }) {
    final label = m['label'] as Map<String, dynamic>?;
    final style = label?['style'] as Map<String, dynamic>?;
    return ApexAnnotation(
      value: (m[key] as num).toDouble(),
      isXAxis: isXAxis,
      borderColor: m['borderColor'] is String
          ? ApexColor.fromHex(m['borderColor'] as String)
          : const Color(0xFF999999),
      labelText: label?['text'] as String?,
      labelColor: style?['color'] is String
          ? ApexColor.fromHex(style!['color'] as String)
          : const Color(0xFFFFFFFF),
      labelBg: style?['background'] is String
          ? ApexColor.fromHex(style!['background'] as String)
          : const Color(0xFF775DD0),
    );
  }
}

/// Axis title text (`xaxis.title.text` / `yaxis.title.text`).
class ApexAxisTitle {
  const ApexAxisTitle({this.text});
  final String? text;
  bool get hasText => text != null && text!.isNotEmpty;

  static ApexAxisTitle parse(Map<String, dynamic>? axis) {
    if (axis == null) return const ApexAxisTitle();
    final title = axis['title'] as Map<String, dynamic>?;
    return ApexAxisTitle(text: title?['text'] as String?);
  }
}

/// Fully-parsed, strongly-typed chart configuration — the apex_dart analogue of
/// ApexCharts' merged options object.
class ApexOptions {
  ApexOptions({
    required this.type,
    required this.series,
    required this.colors,
    this.curve = ApexCurve.straight,
    this.strokeWidth = 2,
    this.dashArray = 0,
    this.categories = const [],
    this.xAxisType = ApexXAxisType.category,
    this.dataLabelsEnabled = false,
    this.legend = const ApexLegend(),
    this.bar = const ApexBarOptions(),
    this.pie = const ApexPieOptions(),
    this.bubble = const ApexBubbleOptions(),
    this.radialBar = const ApexRadialBarOptions(),
    this.heatmap = const ApexHeatmapOptions(),
    this.candlestick = const ApexCandlestickOptions(),
    this.treemap = const ApexTreemapOptions(),
    this.labels = const [],
    this.pieSeries = const [],
    this.stacked = false,
    this.markers = const ApexMarkers(size: 0),
    this.yFormat = const ApexValueFormat(),
    this.xTitle = const ApexAxisTitle(),
    this.yTitle = const ApexAxisTitle(),
    this.zoom = const ApexZoom(),
    this.animations = const ApexAnimations(),
    this.gradient = const ApexGradientFill(),
    this.annotations = const [],
    this.xMin,
    this.xMax,
    this.tickAmount,
    this.tooltipXFormat,
    this.fontFamily,
    this.logarithmic = false,
    this.logBase = 10,
  });

  final ApexChartType type;

  /// Whether bar series are stacked (`chart.stacked: true`).
  final bool stacked;

  /// Point-marker configuration for line/area/scatter.
  final ApexMarkers markers;

  /// Formatter applied to y-values in tooltips, data labels and y-axis labels.
  final ApexValueFormat yFormat;

  /// Axis titles.
  final ApexAxisTitle xTitle;
  final ApexAxisTitle yTitle;

  /// Zoom / pan configuration.
  final ApexZoom zoom;

  /// Mount-animation configuration.
  final ApexAnimations animations;

  /// Gradient fill for area charts.
  final ApexGradientFill gradient;

  /// Y- and X-axis annotation lines.
  final List<ApexAnnotation> annotations;

  /// Initial x-axis window (`xaxis.min` / `xaxis.max`) in domain units (epoch
  /// ms for datetime, index otherwise). null = full extent.
  final double? xMin;
  final double? xMax;

  /// Desired number of x-axis ticks (`xaxis.tickAmount`).
  final int? tickAmount;

  /// Whether the (first) y-axis uses a logarithmic scale (`yaxis.logarithmic`).
  final bool logarithmic;

  /// Logarithm base for a logarithmic y-axis (`yaxis.logBase`, default 10).
  final double logBase;

  /// Tooltip x-date format token string (`tooltip.x.format`, e.g.
  /// `dd MMM yyyy`). null = default "d MMM".
  final String? tooltipXFormat;

  /// Font family for axis/legend/data labels. `null` uses the platform
  /// default. ApexCharts' web default is Helvetica/Arial; pass a metrically
  /// similar family (e.g. Inter) for parity.
  final String? fontFamily;

  /// Cartesian series (line/area/bar/scatter).
  final List<ApexSeries> series;

  /// Radial values (pie/donut/radialBar) paired with [labels].
  final List<double> pieSeries;
  final List<String> labels;

  final List<Color> colors;
  final ApexCurve curve;
  final double strokeWidth;

  /// Dash length for dashed line strokes (`stroke.dashArray`); 0 = solid.
  final double dashArray;
  final List<String> categories;
  final ApexXAxisType xAxisType;
  final bool dataLabelsEnabled;
  final ApexLegend legend;
  final ApexBarOptions bar;
  final ApexPieOptions pie;
  final ApexBubbleOptions bubble;
  final ApexRadialBarOptions radialBar;
  final ApexHeatmapOptions heatmap;
  final ApexCandlestickOptions candlestick;
  final ApexTreemapOptions treemap;

  /// Parse a raw ApexCharts `options` map (the subset apex_dart supports).
  factory ApexOptions.fromJson(Map<String, dynamic> json) {
    final chart = json['chart'] as Map<String, dynamic>? ?? const {};
    final type = ApexChartType.parse(chart['type'] as String?);
    final fontFamily = chart['fontFamily'] as String?;
    final stacked = chart['stacked'] as bool? ?? false;

    final colors = (json['colors'] as List?)
            ?.map((c) => ApexColor.fromHex(c as String))
            .toList() ??
        kApexDefaultPalette.map(ApexColor.fromHex).toList();

    final stroke = json['stroke'] as Map<String, dynamic>?;
    final curve = ApexCurve.parse(stroke?['curve']);
    final strokeWidth = _firstNum(stroke?['width'])?.toDouble() ?? 2;
    final dashArray = _firstNum(stroke?['dashArray'])?.toDouble() ?? 0;

    final xaxis = json['xaxis'] as Map<String, dynamic>?;
    final xAxisType = switch (xaxis?['type']) {
      'datetime' => ApexXAxisType.datetime,
      'numeric' => ApexXAxisType.numeric,
      _ => ApexXAxisType.category,
    };
    final categories =
        (xaxis?['categories'] as List?)?.map((e) => e.toString()).toList() ??
            const <String>[];

    final dataLabels = json['dataLabels'] as Map<String, dynamic>?;
    final dataLabelsEnabled = dataLabels?['enabled'] as bool? ??
        (type.isRadial); // ApexCharts defaults dataLabels on for pies.

    final plotOptions = json['plotOptions'] as Map<String, dynamic>?;
    final bar = ApexBarOptions.parse(
      plotOptions?['bar'] as Map<String, dynamic>?,
    );
    final pie = ApexPieOptions.parse(
      plotOptions?['pie'] as Map<String, dynamic>?,
    );
    final bubble = ApexBubbleOptions.parse(
      plotOptions?['bubble'] as Map<String, dynamic>?,
    );
    final radialBar = ApexRadialBarOptions.parse(
      plotOptions?['radialBar'] as Map<String, dynamic>?,
    );
    final heatmap = ApexHeatmapOptions.parse(
      plotOptions?['heatmap'] as Map<String, dynamic>?,
    );
    final candlestick = ApexCandlestickOptions.parse(
      plotOptions?['candlestick'] as Map<String, dynamic>?,
    );
    final treemap = ApexTreemapOptions.parse(
      plotOptions?['treemap'] as Map<String, dynamic>?,
    );

    final legend = ApexLegend.parse(json['legend'] as Map<String, dynamic>?);

    final markers =
        ApexMarkers.parse(json['markers'] as Map<String, dynamic>?, type);

    // y-value formatter: prefer tooltip.y, fall back to yaxis.labels.
    final tooltip = json['tooltip'] as Map<String, dynamic>?;
    final yaxisList = json['yaxis'];
    final yaxisMap = yaxisList is List
        ? (yaxisList.isNotEmpty
            ? yaxisList.first as Map<String, dynamic>?
            : null)
        : yaxisList as Map<String, dynamic>?;
    final yFormat = ApexValueFormat.parse(
      (tooltip?['y'] as Map<String, dynamic>?) ??
          (yaxisMap?['labels'] as Map<String, dynamic>?),
    );

    final xTitle = ApexAxisTitle.parse(xaxis);
    final yTitle = ApexAxisTitle.parse(yaxisMap);

    final logarithmic = yaxisMap?['logarithmic'] as bool? ?? false;
    final logBase = (yaxisMap?['logBase'] as num?)?.toDouble() ?? 10;

    final xMin = (xaxis?['min'] as num?)?.toDouble();
    final xMax = (xaxis?['max'] as num?)?.toDouble();
    final tickAmount = (xaxis?['tickAmount'] as num?)?.toInt();
    final tooltipXFormat =
        (tooltip?['x'] as Map<String, dynamic>?)?['format'] as String?;
    final gradient =
        ApexGradientFill.parse(json['fill'] as Map<String, dynamic>?, type);
    final annotations = ApexAnnotation.parseAll(
      json['annotations'] as Map<String, dynamic>?,
    );

    final zoom = ApexZoom.parse(
      chart['zoom'] as Map<String, dynamic>?,
      chart['toolbar'] as Map<String, dynamic>?,
      type,
    );
    final animations =
        ApexAnimations.parse(chart['animations'] as Map<String, dynamic>?);

    if (type.isRadial) {
      final pieSeries = (json['series'] as List? ?? const [])
          .map((e) => (e as num).toDouble())
          .toList();
      final labels = (json['labels'] as List? ?? const [])
          .map((e) => e.toString())
          .toList();
      return ApexOptions(
        type: type,
        series: const [],
        pieSeries: pieSeries,
        labels: labels,
        colors: colors,
        dataLabelsEnabled: dataLabelsEnabled,
        legend: legend,
        pie: pie,
        radialBar: radialBar,
        yFormat: yFormat,
        animations: animations,
        fontFamily: fontFamily,
      );
    }

    final series = (json['series'] as List? ?? const [])
        .map((s) => _parseSeries(s as Map<String, dynamic>, xAxisType))
        .toList();

    return ApexOptions(
      type: type,
      series: series,
      colors: colors,
      curve: curve,
      strokeWidth: strokeWidth,
      dashArray: dashArray,
      categories: categories,
      xAxisType: xAxisType,
      dataLabelsEnabled: dataLabelsEnabled,
      legend: legend,
      bar: bar,
      pie: pie,
      bubble: bubble,
      radialBar: radialBar,
      heatmap: heatmap,
      candlestick: candlestick,
      treemap: treemap,
      stacked: stacked,
      markers: markers,
      yFormat: yFormat,
      xTitle: xTitle,
      yTitle: yTitle,
      zoom: zoom,
      animations: animations,
      gradient: gradient,
      annotations: annotations,
      xMin: xMin,
      xMax: xMax,
      tickAmount: tickAmount,
      tooltipXFormat: tooltipXFormat,
      fontFamily: fontFamily,
      logarithmic: logarithmic,
      logBase: logBase,
    );
  }

  /// Returns a copy with the given fields replaced.
  ApexOptions copyWith({
    String? fontFamily,
    bool? animationsEnabled,
  }) {
    return ApexOptions(
      type: type,
      series: series,
      pieSeries: pieSeries,
      labels: labels,
      colors: colors,
      curve: curve,
      strokeWidth: strokeWidth,
      dashArray: dashArray,
      categories: categories,
      xAxisType: xAxisType,
      dataLabelsEnabled: dataLabelsEnabled,
      legend: legend,
      bar: bar,
      pie: pie,
      bubble: bubble,
      radialBar: radialBar,
      heatmap: heatmap,
      candlestick: candlestick,
      treemap: treemap,
      stacked: stacked,
      markers: markers,
      yFormat: yFormat,
      xTitle: xTitle,
      yTitle: yTitle,
      zoom: zoom,
      animations: animationsEnabled == null
          ? animations
          : ApexAnimations(
              enabled: animationsEnabled, speedMs: animations.speedMs),
      gradient: gradient,
      annotations: annotations,
      xMin: xMin,
      xMax: xMax,
      tickAmount: tickAmount,
      tooltipXFormat: tooltipXFormat,
      fontFamily: fontFamily ?? this.fontFamily,
      logarithmic: logarithmic,
      logBase: logBase,
    );
  }

  static ApexSeries _parseSeries(
    Map<String, dynamic> s,
    ApexXAxisType xType,
  ) {
    final name = s['name'] as String? ?? '';
    final rawData = s['data'] as List? ?? const [];
    final points = <ApexPoint>[];
    for (int i = 0; i < rawData.length; i++) {
      final d = rawData[i];
      if (d is List && d.length >= 2) {
        // [x, y] pair, or [x, y, z] triplet for bubbles; y may be null (gap).
        final yv = d[1];
        points.add(ApexPoint(
          x: (d[0] as num).toDouble(),
          y: yv is num ? yv.toDouble() : 0,
          z: d.length >= 3 && d[2] is num ? (d[2] as num).toDouble() : null,
          isNull: yv is! num,
        ));
      } else if (d is Map) {
        final Object? yv = d['y'];
        final Object? xRaw = d['x'];
        final String? label = xRaw is String ? xRaw : null;
        final double? xNum = xRaw is num ? xRaw.toDouble() : null;
        if (yv is List && yv.length >= 4 && yv.every((e) => e is num)) {
          // candlestick: { x: <time>, y: [open, high, low, close] }.
          final o = (yv[0] as num).toDouble();
          final h = (yv[1] as num).toDouble();
          final l = (yv[2] as num).toDouble();
          final c = (yv[3] as num).toDouble();
          points.add(ApexPoint(
            x: xNum,
            y: o,
            ohlc: [o, h, l, c],
            label: label,
          ));
        } else if (yv is List &&
            yv.length >= 2 &&
            yv[0] is num &&
            yv[1] is num) {
          // rangeBar/timeline: { x: <label|value>, y: [start, end] }.
          points.add(ApexPoint(
            x: xNum,
            y: (yv[0] as num).toDouble(),
            yHigh: (yv[1] as num).toDouble(),
            label: label,
          ));
        } else {
          points.add(ApexPoint(
            x: xNum,
            y: yv is num ? yv.toDouble() : 0,
            z: (d['z'] as num?)?.toDouble(),
            label: label,
            isNull: yv is! num,
          ));
        }
      } else if (d is num) {
        points.add(ApexPoint(x: null, y: d.toDouble()));
      } else {
        // bare null in the data array → gap at this index.
        points.add(const ApexPoint(x: null, y: 0, isNull: true));
      }
    }
    return ApexSeries(name: name, points: points);
  }
}

/// "70%" -> 0.7, 0.5 -> 0.5, null -> null.
double? _parsePercent(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) {
    final s = v.replaceAll('%', '').trim();
    final n = double.tryParse(s);
    if (n == null) return null;
    return s == v ? n : n / 100.0;
  }
  return null;
}

num? _firstNum(Object? v) {
  if (v == null) return null;
  if (v is num) return v;
  if (v is List && v.isNotEmpty && v.first is num) return v.first as num;
  return null;
}
