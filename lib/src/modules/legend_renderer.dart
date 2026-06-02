import 'dart:math' as math;
import 'dart:ui';

import '../options/apex_options.dart';
import '../svg/text_drawer.dart';

/// Renders the series legend, ported from ApexCharts' default `Legend`
/// behaviour: small rounded color markers followed by the series name, laid
/// out horizontally (top/bottom) or vertically (left/right).
class LegendRenderer {
  const LegendRenderer._();

  static const double _markerSize = 12;
  static const double _markerGap = 5;
  static const double _itemGap = 14;
  static const Color _textColor = Color(0xFF373D3F);

  /// Height reserved for a horizontal (top/bottom) legend, or 0 if none.
  static double reservedHeight(ApexOptions options) {
    final pos = options.legend.position;
    if (pos == ApexLegendPosition.bottom || pos == ApexLegendPosition.top) {
      return 26;
    }
    return 0;
  }

  /// Width reserved for a vertical (left/right) legend, or 0 if none.
  static double reservedWidth(ApexOptions options) {
    final pos = options.legend.position;
    if (pos != ApexLegendPosition.left && pos != ApexLegendPosition.right) {
      return 0;
    }
    final labeller = TextDrawer(fontFamily: options.fontFamily, fontSize: 12);
    double widest = 0;
    for (final name in _names(options)) {
      widest = math.max(widest, labeller.measure(name).width);
    }
    return _markerSize + _markerGap + widest + 24;
  }

  /// Draw the legend within [canvasSize], using [colors] aligned with the
  /// entries returned by [_names].
  static void paint(
    Canvas canvas,
    Size canvasSize,
    ApexOptions options,
  ) {
    final pos = options.legend.position;
    if (pos == ApexLegendPosition.none) return;

    final names = _names(options);
    if (names.isEmpty) return;

    final labeller =
        TextDrawer(color: _textColor, fontFamily: options.fontFamily, fontSize: 12);

    switch (pos) {
      case ApexLegendPosition.bottom:
        _paintHorizontal(
            canvas, canvasSize, options, names, labeller, canvasSize.height - 18);
      case ApexLegendPosition.top:
        _paintHorizontal(canvas, canvasSize, options, names, labeller, 6);
      case ApexLegendPosition.right:
        _paintVertical(
          canvas,
          options,
          names,
          labeller,
          canvasSize.width - reservedWidth(options) + 12,
          canvasSize.height,
        );
      case ApexLegendPosition.left:
        _paintVertical(
          canvas,
          options,
          names,
          labeller,
          12,
          canvasSize.height,
        );
      case ApexLegendPosition.none:
        break;
    }
  }

  static void _paintHorizontal(
    Canvas canvas,
    Size size,
    ApexOptions options,
    List<String> names,
    TextDrawer labeller,
    double top,
  ) {
    // Measure total width to center the row.
    double total = 0;
    final widths = <double>[];
    for (final n in names) {
      final w = _markerSize + _markerGap + labeller.measure(n).width;
      widths.add(w);
      total += w + _itemGap;
    }
    total -= _itemGap;

    double x = (size.width - total) / 2;
    final double markerY = top + 6;
    for (int i = 0; i < names.length; i++) {
      _marker(canvas, Offset(x, markerY), _colorFor(options, i));
      labeller.draw(
        canvas,
        names[i],
        Offset(x + _markerSize + _markerGap, top),
        anchor: TextAnchor.start,
      );
      x += widths[i] + _itemGap;
    }
  }

  static void _paintVertical(
    Canvas canvas,
    ApexOptions options,
    List<String> names,
    TextDrawer labeller,
    double left,
    double canvasHeight,
  ) {
    const lineHeight = 20.0;
    final totalHeight = names.length * lineHeight;
    double y = (canvasHeight - totalHeight) / 2;
    for (int i = 0; i < names.length; i++) {
      _marker(canvas, Offset(left, y + 4), _colorFor(options, i));
      labeller.draw(
        canvas,
        names[i],
        Offset(left + _markerSize + _markerGap, y),
        anchor: TextAnchor.start,
      );
      y += lineHeight;
    }
  }

  static void _marker(Canvas canvas, Offset topLeft, Color color) {
    final rect = Rect.fromLTWH(topLeft.dx, topLeft.dy, _markerSize, _markerSize);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = color,
    );
  }

  static List<String> _names(ApexOptions options) {
    if (options.type.isRadial) return options.labels;
    return options.series.map((s) => s.name).toList();
  }

  static Color _colorFor(ApexOptions options, int i) {
    return options.colors[i % options.colors.length];
  }
}
