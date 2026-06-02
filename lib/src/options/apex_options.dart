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
class ApexPoint {
  const ApexPoint({this.x, required this.y});
  final double? x;
  final double y;
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

/// Fully-parsed, strongly-typed chart configuration — the apex_dart analogue of
/// ApexCharts' merged options object.
class ApexOptions {
  ApexOptions({
    required this.type,
    required this.series,
    required this.colors,
    this.curve = ApexCurve.straight,
    this.strokeWidth = 2,
    this.categories = const [],
    this.xAxisType = ApexXAxisType.category,
    this.dataLabelsEnabled = false,
    this.legend = const ApexLegend(),
    this.bar = const ApexBarOptions(),
    this.pie = const ApexPieOptions(),
    this.labels = const [],
    this.pieSeries = const [],
    this.stacked = false,
    this.fontFamily,
  });

  final ApexChartType type;

  /// Whether bar series are stacked (`chart.stacked: true`).
  final bool stacked;

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
      categories: categories,
      xAxisType: xAxisType,
      dataLabelsEnabled: dataLabelsEnabled,
      legend: legend,
      bar: bar,
      pie: pie,
      stacked: stacked,
      fontFamily: fontFamily,
    );
  }

  /// Returns a copy with the given fields replaced.
  ApexOptions copyWith({String? fontFamily}) {
    return ApexOptions(
      type: type,
      series: series,
      pieSeries: pieSeries,
      labels: labels,
      colors: colors,
      curve: curve,
      strokeWidth: strokeWidth,
      categories: categories,
      xAxisType: xAxisType,
      dataLabelsEnabled: dataLabelsEnabled,
      legend: legend,
      bar: bar,
      pie: pie,
      stacked: stacked,
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
        // [x, y] pair (datetime/numeric).
        points.add(ApexPoint(
          x: (d[0] as num).toDouble(),
          y: (d[1] as num).toDouble(),
        ));
      } else if (d is Map) {
        points.add(ApexPoint(
          x: (d['x'] as num?)?.toDouble(),
          y: (d['y'] as num).toDouble(),
        ));
      } else if (d is num) {
        points.add(ApexPoint(x: null, y: d.toDouble()));
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
