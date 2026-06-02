import 'dart:ui';

import 'package:flutter/painting.dart';

import '../options/apex_options.dart';
import '../svg/text_drawer.dart';
import '../utils/format_value.dart';
import 'cartesian_layout.dart';

/// Draws static data labels on cartesian charts, ported from ApexCharts v4.7.0
/// `src/modules/DataLabels.js` default positioning:
///   * line / area / scatter: label centered above each point (offsetY ~ -5,
///     so the text baseline sits a few px above the marker).
///   * column (vertical bar): label centered horizontally over the bar, just
///     above its top edge.
///   * horizontal bar: label centered vertically, just outside the bar end.
///
/// ApexCharts hides data labels by default for line/area (`dataLabels.enabled:
/// false`) but shows them when enabled; callers gate on
/// [ApexOptions.dataLabelsEnabled].
class DataLabelsRenderer {
  const DataLabelsRenderer._();

  static const Color _labelColor = Color(0xFF373D3F);

  static void paint(
    Canvas canvas,
    CartesianLayout layout,
    ApexOptions options,
  ) {
    if (!options.dataLabelsEnabled) return;

    final labeller = TextDrawer(
      color: _labelColor,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      fontFamily: options.fontFamily,
    );

    switch (options.type) {
      case ApexChartType.bar:
        if (options.bar.horizontal) {
          _horizontalBarLabels(canvas, layout, options, labeller);
        } else {
          _columnLabels(canvas, layout, options, labeller);
        }
      case ApexChartType.line:
      case ApexChartType.area:
      case ApexChartType.scatter:
        _pointLabels(canvas, layout, options, labeller);
      default:
        break;
    }
  }

  static void _pointLabels(
    Canvas canvas,
    CartesianLayout layout,
    ApexOptions options,
    TextDrawer labeller,
  ) {
    for (int i = 0; i < options.series.length; i++) {
      final s = options.series[i];
      for (int j = 0; j < s.points.length; j++) {
        final p = s.points[j];
        final double x = options.xAxisType == ApexXAxisType.category
            ? layout.xCategoryToPixel(j)
            : layout.xValueToPixel(p.x ?? j.toDouble());
        final double y = layout.yToPixel(p.y) - 8;
        labeller.draw(
          canvas,
          FormatValue.formatted(p.y, options.yFormat),
          Offset(x, y),
          anchor: TextAnchor.middle,
        );
      }
    }
  }

  static void _columnLabels(
    Canvas canvas,
    CartesianLayout layout,
    ApexOptions options,
    TextDrawer labeller,
  ) {
    final seriesLen = options.series.length;
    if (seriesLen == 0 || layout.pointCount == 0) return;

    if (options.stacked) {
      for (int j = 0; j < layout.pointCount; j++) {
        final double cx = layout.xBandCenter(j);
        double acc = 0;
        for (int i = 0; i < seriesLen; i++) {
          final s = options.series[i];
          if (j >= s.points.length) continue;
          final v = s.points[j].y;
          final yMid = layout.yToPixel(acc + v / 2);
          acc += v;
          labeller.draw(
            canvas,
            FormatValue.formatted(v, options.yFormat),
            Offset(cx, yMid),
            anchor: TextAnchor.middle,
            verticalCenter: true,
          );
        }
      }
      return;
    }

    final double xDivision = layout.bandWidth;
    final double barWidth =
        (xDivision / seriesLen) * options.bar.columnWidthFraction;
    final double groupPad = (xDivision - barWidth * seriesLen) / 2;
    for (int j = 0; j < layout.pointCount; j++) {
      final double bandLeft =
          layout.xBandCenter(j) - xDivision / 2 + groupPad;
      for (int i = 0; i < seriesLen; i++) {
        final s = options.series[i];
        if (j >= s.points.length) continue;
        final v = s.points[j].y;
        final cx = bandLeft + i * barWidth + barWidth / 2;
        final top = layout.yToPixel(v) - 8;
        labeller.draw(
          canvas,
          FormatValue.formatted(v, options.yFormat),
          Offset(cx, top),
          anchor: TextAnchor.middle,
        );
      }
    }
  }

  static void _horizontalBarLabels(
    Canvas canvas,
    CartesianLayout layout,
    ApexOptions options,
    TextDrawer labeller,
  ) {
    final seriesLen = options.series.length;
    final double yDivision = layout.plotRect.height / layout.pointCount;

    double valueToX(num v) {
      final t = (v - layout.yMin) /
          ((layout.yMax - layout.yMin) == 0 ? 1 : layout.yMax - layout.yMin);
      return layout.plotRect.left + t * layout.plotRect.width;
    }

    for (int j = 0; j < layout.pointCount; j++) {
      final double bandTop = layout.plotRect.top + j * yDivision;
      final double barH =
          (yDivision / seriesLen) * options.bar.columnWidthFraction;
      final double groupPad = (yDivision - barH * seriesLen) / 2;
      for (int i = 0; i < seriesLen; i++) {
        final s = options.series[i];
        if (j >= s.points.length) continue;
        final v = s.points[j].y;
        final cy = bandTop + groupPad + i * barH + barH / 2;
        final endX = valueToX(v) + (v >= 0 ? 6 : -6);
        labeller.draw(
          canvas,
          FormatValue.formatted(v, options.yFormat),
          Offset(endX, cy),
          anchor: v >= 0 ? TextAnchor.start : TextAnchor.end,
          verticalCenter: true,
        );
      }
    }
  }
}
