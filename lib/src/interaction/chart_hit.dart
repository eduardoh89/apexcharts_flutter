import 'dart:ui';

/// One row in a tooltip: a colored marker, the series name, and the formatted
/// value. Mirrors the per-series entries ApexCharts prints in its tooltip.
class TooltipSeriesValue {
  const TooltipSeriesValue({
    required this.color,
    required this.seriesName,
    required this.formattedValue,
    this.highlighted = false,
  });

  final Color color;
  final String seriesName;
  final String formattedValue;

  /// Whether this row corresponds to the exact series under the cursor
  /// (ApexCharts bolds the focused row in a shared tooltip).
  final bool highlighted;

  @override
  bool operator ==(Object other) =>
      other is TooltipSeriesValue &&
      other.color == color &&
      other.seriesName == seriesName &&
      other.formattedValue == formattedValue &&
      other.highlighted == highlighted;

  @override
  int get hashCode =>
      Object.hash(color, seriesName, formattedValue, highlighted);
}

/// The result of hit-testing the chart at a pointer position: everything the
/// tooltip overlay needs to render, plus the focal point for the crosshair and
/// active markers.
class ChartHit {
  const ChartHit({
    required this.title,
    required this.rows,
    required this.anchor,
    this.markerPoints = const [],
    this.crosshairX,
  });

  /// Tooltip heading (the x category / date / value), may be empty.
  final String title;

  /// One row per series shown in this tooltip.
  final List<TooltipSeriesValue> rows;

  /// Pixel position the tooltip should point at (the focused datum).
  final Offset anchor;

  /// Points to draw active markers on (line/area shared tooltip highlights
  /// every series at the focused x).
  final List<MarkerPoint> markerPoints;

  /// If set, draw a vertical crosshair line at this x (cartesian shared mode).
  final double? crosshairX;

  @override
  bool operator ==(Object other) {
    if (other is! ChartHit) return false;
    if (other.title != title ||
        other.anchor != anchor ||
        other.crosshairX != crosshairX ||
        other.rows.length != rows.length ||
        other.markerPoints.length != markerPoints.length) {
      return false;
    }
    for (int i = 0; i < rows.length; i++) {
      if (other.rows[i] != rows[i]) return false;
    }
    for (int i = 0; i < markerPoints.length; i++) {
      if (other.markerPoints[i] != markerPoints[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        title,
        anchor,
        crosshairX,
        Object.hashAll(rows),
        Object.hashAll(markerPoints),
      );
}

/// A marker the tooltip highlights on the plot (filled circle with halo).
class MarkerPoint {
  const MarkerPoint({required this.position, required this.color});
  final Offset position;
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is MarkerPoint &&
      other.position == position &&
      other.color == color;

  @override
  int get hashCode => Object.hash(position, color);
}
