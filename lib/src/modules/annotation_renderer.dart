import 'package:flutter/painting.dart';

import '../options/apex_options.dart';
import '../svg/text_drawer.dart';
import 'cartesian_layout.dart';

/// Draws ApexCharts `annotations.yaxis[]` / `annotations.xaxis[]`: dashed
/// guide lines at a fixed axis value with an optional colored label pill.
class AnnotationRenderer {
  const AnnotationRenderer._();

  static void paint(
    Canvas canvas,
    CartesianLayout layout,
    ApexOptions options,
  ) {
    if (options.annotations.isEmpty) return;
    final plot = layout.plotRect;

    for (final a in options.annotations) {
      final linePaint = Paint()
        ..color = a.borderColor
        ..strokeWidth = 1;

      if (a.isXAxis) {
        // Vertical line at an x value; skip if outside the visible window.
        if (a.value < layout.xViewMin || a.value > layout.xViewMax) continue;
        final x = layout.xValueToPixel(a.value);
        _dashedLine(
          canvas,
          Offset(x, plot.top),
          Offset(x, plot.bottom),
          linePaint,
        );
        if (a.labelText != null) {
          _label(canvas, a, Offset(x, plot.top + 2), options, centerX: true);
        }
      } else {
        // Horizontal line at a y value.
        final y = layout.yToPixel(a.value);
        if (y < plot.top || y > plot.bottom) continue;
        _dashedLine(
          canvas,
          Offset(plot.left, y),
          Offset(plot.right, y),
          linePaint,
        );
        if (a.labelText != null) {
          _label(canvas, a, Offset(plot.right - 4, y), options,
              centerX: false);
        }
      }
    }
  }

  static void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 5.0;
    const gap = 4.0;
    final total = (b - a).distance;
    final dir = (b - a) / (total == 0 ? 1 : total);
    double d = 0;
    while (d < total) {
      final start = a + dir * d;
      final end = a + dir * (d + dash).clamp(0, total);
      canvas.drawLine(start, end, paint);
      d += dash + gap;
    }
  }

  static void _label(
    Canvas canvas,
    ApexAnnotation a,
    Offset at,
    ApexOptions options, {
    required bool centerX,
  }) {
    final drawer = TextDrawer(
      color: a.labelColor,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      fontFamily: options.fontFamily,
    );
    final size = drawer.measure(a.labelText!);
    const padH = 6.0;
    const padV = 3.0;
    final boxW = size.width + padH * 2;
    final boxH = size.height + padV * 2;

    // Pill anchored: x-annotation → centered on the line at the top;
    // y-annotation → right-aligned at the line.
    final double left = centerX ? at.dx - boxW / 2 : at.dx - boxW;
    final double top = at.dy;

    final rect = Rect.fromLTWH(left, top, boxW, boxH);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()..color = a.labelBg,
    );
    drawer.draw(
      canvas,
      a.labelText!,
      Offset(left + padH, top + padV),
      anchor: TextAnchor.start,
    );
  }
}
