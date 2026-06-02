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
  radialBar,
  heatmap;

  static ApexChartType parse(String? v) {
    switch (v) {
      case 'area':
        return ApexChartType.area;
      case 'bar':
        return ApexChartType.bar;
      case 'pie':
        return ApexChartType.pie;
      case 'donut':
        return ApexChartType.donut;
      case 'scatter':
        return ApexChartType.scatter;
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
      this == line || this == area || this == bar || this == scatter;
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
  const ApexPoint({this.x, required this.y, this.isNull = false});
  final double? x;
  final double y;
  final bool isNull;
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

class ApexLegend {
  const ApexLegend({this.position = ApexLegendPosition.bottom});
  final ApexLegendPosition position;

  static ApexLegend parse(Map<String, dynamic>? json) {
    if (json == null) return const ApexLegend();
    final show = json['show'];
    if (show == false) {
      return const ApexLegend(position: ApexLegendPosition.none);
    }
    switch (json['position']) {
      case 'top':
        return const ApexLegend(position: ApexLegendPosition.top);
      case 'right':
        return const ApexLegend(position: ApexLegendPosition.right);
      case 'left':
        return const ApexLegend(position: ApexLegendPosition.left);
      case 'bottom':
        return const ApexLegend(position: ApexLegendPosition.bottom);
      default:
        return const ApexLegend();
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

  /// Fraction (0..1) of the category slot occupied by the bar group.
  final double columnWidthFraction;
  final double borderRadius;

  static ApexBarOptions parse(Map<String, dynamic>? bar) {
    if (bar == null) return const ApexBarOptions();
    return ApexBarOptions(
      horizontal: bar['horizontal'] as bool? ?? false,
      columnWidthFraction: _parsePercent(bar['columnWidth']) ?? 0.7,
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
    final hoverSize = _firstNum(hover?['size'])?.toDouble() ??
        (size > 0 ? size + 3 : 6);
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

  static ApexGradientFill parse(Map<String, dynamic>? fill) {
    if (fill == null) return const ApexGradientFill(enabled: true);
    final isGradient = fill['type'] == 'gradient';
    final g = fill['gradient'] as Map<String, dynamic>?;
    return ApexGradientFill(
      enabled: isGradient || g != null,
      opacityFrom: (g?['opacityFrom'] as num?)?.toDouble() ?? 0.65,
      opacityTo: (g?['opacityTo'] as num?)?.toDouble() ?? 0.05,
      stops: (g?['stops'] as List?)?.map((e) => (e as num).toDouble()).toList() ??
          const [0, 100],
      shade: g?['shade'] as String? ?? 'dark',
      shadeIntensity: (g?['shadeIntensity'] as num?)?.toDouble() ?? 0.5,
      inverseColors: g?['inverseColors'] as bool? ?? true,
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
    final categories = (xaxis?['categories'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
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

    final legend = ApexLegend.parse(json['legend'] as Map<String, dynamic>?);

    final markers =
        ApexMarkers.parse(json['markers'] as Map<String, dynamic>?, type);

    // y-value formatter: prefer tooltip.y, fall back to yaxis.labels.
    final tooltip = json['tooltip'] as Map<String, dynamic>?;
    final yaxisList = json['yaxis'];
    final yaxisMap = yaxisList is List
        ? (yaxisList.isNotEmpty ? yaxisList.first as Map<String, dynamic>? : null)
        : yaxisList as Map<String, dynamic>?;
    final yFormat = ApexValueFormat.parse(
      (tooltip?['y'] as Map<String, dynamic>?) ??
          (yaxisMap?['labels'] as Map<String, dynamic>?),
    );

    final xTitle = ApexAxisTitle.parse(xaxis);
    final yTitle = ApexAxisTitle.parse(yaxisMap);

    final xMin = (xaxis?['min'] as num?)?.toDouble();
    final xMax = (xaxis?['max'] as num?)?.toDouble();
    final tickAmount = (xaxis?['tickAmount'] as num?)?.toInt();
    final tooltipXFormat =
        (tooltip?['x'] as Map<String, dynamic>?)?['format'] as String?;
    final gradient = ApexGradientFill.parse(json['fill'] as Map<String, dynamic>?);
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
      final labels =
          (json['labels'] as List? ?? const []).map((e) => e.toString()).toList();
      return ApexOptions(
        type: type,
        series: const [],
        pieSeries: pieSeries,
        labels: labels,
        colors: colors,
        dataLabelsEnabled: dataLabelsEnabled,
        legend: legend,
        pie: pie,
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
      stacked: stacked,
      markers: markers,
      yFormat: yFormat,
      xTitle: xTitle,
      yTitle: yTitle,
      zoom: zoom,
      animations: animationsEnabled == null
          ? animations
          : ApexAnimations(enabled: animationsEnabled, speedMs: animations.speedMs),
      gradient: gradient,
      annotations: annotations,
      xMin: xMin,
      xMax: xMax,
      tickAmount: tickAmount,
      tooltipXFormat: tooltipXFormat,
      fontFamily: fontFamily ?? this.fontFamily,
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
        // [x, y] pair (datetime/numeric); y may be null (gap).
        final yv = d[1];
        points.add(ApexPoint(
          x: (d[0] as num).toDouble(),
          y: yv is num ? yv.toDouble() : 0,
          isNull: yv is! num,
        ));
      } else if (d is Map) {
        final yv = d['y'];
        points.add(ApexPoint(
          x: (d['x'] as num?)?.toDouble(),
          y: yv is num ? yv.toDouble() : 0,
          isNull: yv is! num,
        ));
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
