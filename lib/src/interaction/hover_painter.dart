import 'dart:ui';

import '../modules/cartesian_layout.dart';
import 'chart_hit.dart';

/// Paints the hover affordances ApexCharts shows alongside its tooltip:
///   * a vertical crosshair line at the focused x (shared cartesian tooltip),
///     styled like ApexCharts' `.apexcharts-xcrosshairs` (faint grey fill).
///   * an "active" marker on each highlighted datum: a filled dot with a
///     lighter halo, matching `LinePointHighlighter` / dynamic tooltip markers.
class HoverPainter {
  const HoverPainter._();

  static const Color _crosshair = Color(0x14000000);

  static void paint(
    Canvas canvas,
    ChartHit hit,
    CartesianLayout? layout,
  ) {
    if (hit.crosshairX != null && layout != null) {
      final paint = Paint()
        ..color = _crosshair
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(hit.crosshairX!, layout.plotRect.top),
        Offset(hit.crosshairX!, layout.plotRect.bottom),
        paint,
      );
    }

    for (final m in hit.markerPoints) {
      // Halo.
      canvas.drawCircle(
        m.position,
        6,
        Paint()..color = m.color.withValues(alpha: 0.25),
      );
      // Solid center with white ring (ApexCharts active marker).
      canvas.drawCircle(m.position, 4, Paint()..color = m.color);
      canvas.drawCircle(
        m.position,
        4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFFFFFFF),
      );
    }
  }
}
