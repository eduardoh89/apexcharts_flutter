import 'dart:ui';

import '../options/apex_options.dart';
import '../svg/text_drawer.dart';
import 'cartesian_layout.dart';

/// Draws the cartesian chart chrome: horizontal gridlines, y-axis labels and
/// x-axis labels. Mirrors ApexCharts' default light theme:
///   * gridlines  #e0e6ed (borderColor)
///   * axis labels #6e8192-ish, 11px
class GridRenderer {
  const GridRenderer._();

  static const Color _gridLine = Color(0xFFE0E6ED);
  static const Color _labelColor = Color(0xFF373D3F);

  static void paint(
    Canvas canvas,
    CartesianLayout layout,
    ApexOptions options,
  ) {
    final gridPaint = Paint()
      ..color = _gridLine
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final labeller = TextDrawer(
      color: _labelColor.withValues(alpha: 0.85),
      fontFamily: options.fontFamily,
    );

    // Horizontal gridlines + y labels at each tick.
    for (final tick in layout.yTicks) {
      final y = layout.yToPixel(tick);
      canvas.drawLine(
        Offset(layout.plotRect.left, y),
        Offset(layout.plotRect.right, y),
        gridPaint,
      );
      labeller.draw(
        canvas,
        _fmtNum(tick),
        Offset(layout.plotRect.left - 10, y),
        anchor: TextAnchor.end,
        verticalCenter: true,
      );
    }

    _paintXLabels(canvas, layout, options, labeller);
  }

  static void _paintXLabels(
    Canvas canvas,
    CartesianLayout layout,
    ApexOptions options,
    TextDrawer labeller,
  ) {
    final double labelY = layout.plotRect.bottom + 8;

    if (options.xAxisType == ApexXAxisType.category) {
      final cats = layout.xCategories;
      final n = layout.pointCount;
      // Bars label the center of each category band; line/area label the
      // point position (edge-to-edge).
      final bool banded = options.type == ApexChartType.bar;
      for (int i = 0; i < n; i++) {
        final label = i < cats.length ? cats[i] : (i + 1).toString();
        final x =
            banded ? layout.xBandCenter(i) : layout.xCategoryToPixel(i);
        labeller.draw(
          canvas,
          label,
          Offset(x, labelY),
          anchor: TextAnchor.middle,
        );
      }
    } else {
      // datetime/numeric: a handful of evenly spaced ticks.
      const desired = 6;
      for (int i = 0; i <= desired; i++) {
        final t = i / desired;
        final value =
            layout.xNumericMin + t * (layout.xNumericMax - layout.xNumericMin);
        final x = layout.plotRect.left + t * layout.plotRect.width;
        final label = options.xAxisType == ApexXAxisType.datetime
            ? _fmtDate(value)
            : _fmtNum(value);
        labeller.draw(
          canvas,
          label,
          Offset(x, labelY),
          anchor: TextAnchor.middle,
        );
      }
    }
  }

  static String _fmtNum(num v) {
    if (v == v.truncate()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  static String _fmtDate(double msEpoch) {
    final d = DateTime.fromMillisecondsSinceEpoch(msEpoch.round());
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}
