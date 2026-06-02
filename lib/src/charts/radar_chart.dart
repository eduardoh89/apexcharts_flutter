import 'dart:math' as math;
import 'dart:ui';

import '../options/apex_options.dart';
import '../svg/text_drawer.dart';
import '../utils/range.dart';

/// Renders radar (spider) charts, ported from ApexCharts v4.7.0
/// `src/charts/Radar.js`.
///
/// Geometry (from `Radar`):
///   * disAngle = 2π / dataPointsLen, vertex j at angle `j * disAngle`
///   * point.x = radius * sin(angle), point.y = -radius * cos(angle)
///     (0 at 12 o'clock, going clockwise — `getDataPointsPos`)
///   * dataRadius = ((value - minValue) / |maxValue - minValue|) * size
///   * background grid = concentric polygons at the y-axis tick layers
///     (`drawPolygons`), with spokes from the center to each vertex.
/// minValue/maxValue come from the nice y-scale (`w.globals.minY/maxY`).
class RadarChartRenderer {
  const RadarChartRenderer._();

  static const Color _polygonStroke = Color(0xFFE8E8E8);
  static const Color _axisLabel = Color(0xFFA8A8A8);

  static void paint(Canvas canvas, Size size, ApexOptions options) {
    if (options.series.isEmpty) return;
    int dataPointsLen = 0;
    for (final s in options.series) {
      dataPointsLen = math.max(dataPointsLen, s.points.length);
    }
    if (dataPointsLen == 0) return;

    // Nice y-scale gives the ring layers and the min/max used to normalise.
    double yLo = double.infinity, yHi = -double.infinity;
    for (final s in options.series) {
      for (final p in s.points) {
        if (p.isNull) continue;
        yLo = math.min(yLo, p.y);
        yHi = math.max(yHi, p.y);
      }
    }
    if (!yLo.isFinite) {
      yLo = 0;
      yHi = 1;
    }
    final scale = options.logarithmic
        ? NiceScale.logarithmicScale(yLo, yHi, base: options.logBase)
        : NiceScale.niceScale(yLo, yHi);
    final double minValue = scale.niceMin.toDouble();
    final double maxValue = scale.niceMax.toDouble();
    final double range = (maxValue - minValue).abs() == 0
        ? 1
        : (maxValue - minValue).abs();

    // Reserve room for the outer x-axis labels (Radar shrinks `size`).
    final labeller =
        TextDrawer(color: _axisLabel, fontSize: 11, fontFamily: options.fontFamily);
    double widestLabel = 0;
    for (int j = 0; j < dataPointsLen; j++) {
      final lbl = j < options.categories.length ? options.categories[j] : '';
      widestLabel = math.max(widestLabel, labeller.measure(lbl).width);
    }

    final double defaultSize = math.min(size.width, size.height);
    final double radius =
        defaultSize / 2.1 - options.strokeWidth - widestLabel / 1.75;
    if (radius <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final double disAngle = (math.pi * 2) / dataPointsLen;

    Offset vertex(double r, int j) {
      final angle = j * disAngle;
      return Offset(
        center.dx + r * math.sin(angle),
        center.dy - r * math.cos(angle),
      );
    }

    // --- Background polygons (one per y tick layer) + spokes. ---
    final int layers = scale.result.length;
    if (layers >= 2) {
      final double layerDis = radius / (layers - 1);
      final polyPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _polygonStroke
        ..isAntiAlias = true;
      for (int l = 0; l < layers; l++) {
        final double r = layerDis * l;
        final path = Path();
        for (int j = 0; j < dataPointsLen; j++) {
          final v = vertex(r, j);
          if (j == 0) {
            path.moveTo(v.dx, v.dy);
          } else {
            path.lineTo(v.dx, v.dy);
          }
        }
        path.close();
        canvas.drawPath(path, polyPaint);
      }
      // Spokes from center to outer vertices.
      for (int j = 0; j < dataPointsLen; j++) {
        final v = vertex(radius, j);
        canvas.drawLine(center, v, polyPaint);
      }

      // Y-axis tick labels up the first spoke (vertex 0 = straight up), one per
      // layer (`Radar.drawPolygons` draws yaxisTexts at the first vertex).
      final yLabeller = TextDrawer(
        color: const Color(0xFF6E8192),
        fontSize: 11,
        fontFamily: options.fontFamily,
      );
      for (int l = 0; l < layers; l++) {
        final v = vertex(layerDis * l, 0);
        yLabeller.draw(
          canvas,
          _fmtNum(scale.result[l]),
          Offset(v.dx - 6, v.dy),
          anchor: TextAnchor.end,
          verticalCenter: true,
        );
      }
    }

    // --- Series polygons (fill + stroke). ---
    for (int i = 0; i < options.series.length; i++) {
      final s = options.series[i];
      final color = s.color ?? options.colors[i % options.colors.length];
      final path = Path();
      bool started = false;
      for (int j = 0; j < dataPointsLen; j++) {
        if (j >= s.points.length) break;
        final p = s.points[j];
        final double pct = ((p.y - minValue) / range).clamp(0.0, 1.0);
        final v = vertex(pct * radius, j);
        if (!started) {
          path.moveTo(v.dx, v.dy);
          started = true;
        } else {
          path.lineTo(v.dx, v.dy);
        }
      }
      path.close();

      // ApexCharts fills radar areas at low opacity over a colored stroke.
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: 0.2)
          ..isAntiAlias = true,
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = options.strokeWidth <= 0 ? 2 : options.strokeWidth
          ..color = color
          ..isAntiAlias = true,
      );

      // Vertex markers.
      for (int j = 0; j < dataPointsLen; j++) {
        if (j >= s.points.length) break;
        final p = s.points[j];
        final double pct = ((p.y - minValue) / range).clamp(0.0, 1.0);
        final v = vertex(pct * radius, j);
        canvas.drawCircle(v, 3, Paint()..color = color);
      }
    }

    // --- Outer category (x-axis) labels at each vertex. ---
    for (int j = 0; j < dataPointsLen; j++) {
      final lbl = j < options.categories.length ? options.categories[j] : '';
      if (lbl.isEmpty) continue;
      final v = vertex(radius, j);
      final double dx = v.dx - center.dx;
      TextAnchor anchor;
      if (dx.abs() < 10) {
        anchor = TextAnchor.middle;
      } else if (dx > 0) {
        anchor = TextAnchor.start;
      } else {
        anchor = TextAnchor.end;
      }
      final double ox = dx > 10 ? 8 : (dx < -10 ? -8 : 0);
      final double oy = (v.dy - center.dy) > 0 ? 10 : -4;
      labeller.draw(
        canvas,
        lbl,
        Offset(v.dx + ox, v.dy + oy),
        anchor: anchor,
        verticalCenter: true,
      );
    }
  }

  static String _fmtNum(num v) {
    if (v == v.truncate()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}
