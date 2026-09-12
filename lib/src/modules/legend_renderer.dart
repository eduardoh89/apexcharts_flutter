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

  /// Whether the legend should be drawn at all. Ported from
  /// `Legend.init()` `showLegendAlways`: an axis chart with a single series
  /// hides the legend unless `legend.showForSingleSeries` is set; non-axis
  /// charts (pie/donut/radialBar) always show it. `legend.show:false` (parsed
  /// as position `none`) suppresses it entirely.
  static bool _shouldShow(ApexOptions options) {
    if (options.legend.position == ApexLegendPosition.none) return false;
    final names = _names(options);
    if (names.isEmpty) return false;
    final bool axisChart = options.type.isCartesian;
    if (!axisChart) return true; // pie/donut/radialBar always show.
    final showAlways =
        (options.legend.showForSingleSeries && names.length == 1) ||
            names.length > 1;
    return showAlways;
  }

  /// Height reserved for a horizontal (top/bottom) legend, or 0 if none.
  /// [maxWidth] is the space the legend actually has to lay out in (the
  /// chart's own width) — a legend whose items don't fit on one line wraps
  /// to as many rows as it needs, at 26px each, so this and [_paintHorizontal]
  /// always agree on how many rows there are.
  static double reservedHeight(ApexOptions options, double maxWidth) {
    if (!_shouldShow(options)) return 0;
    final pos = options.legend.position;
    if (pos == ApexLegendPosition.bottom || pos == ApexLegendPosition.top) {
      final labeller = TextDrawer(fontFamily: options.fontFamily, fontSize: 12);
      final rows = _wrapRows(_names(options), labeller, maxWidth);
      return rows.length * 26.0;
    }
    return 0;
  }

  /// Greedy line-fill: keep adding items to the current row while they fit
  /// in [maxWidth], start a new row once the next one wouldn't. Pure — no
  /// canvas needed — so [reservedHeight] and [_paintHorizontal] can share it
  /// and never disagree on where the rows break. Returns item indices per
  /// row, in [names] order.
  static List<List<int>> _wrapRows(
    List<String> names,
    TextDrawer labeller,
    double maxWidth,
  ) {
    final rows = <List<int>>[];
    var current = <int>[];
    var currentWidth = 0.0;
    for (int i = 0; i < names.length; i++) {
      final itemWidth = _markerSize + _markerGap + labeller.measure(names[i]).width;
      final addedWidth = current.isEmpty ? itemWidth : itemWidth + _itemGap;
      if (current.isNotEmpty && currentWidth + addedWidth > maxWidth) {
        rows.add(current);
        current = [i];
        currentWidth = itemWidth;
      } else {
        current.add(i);
        currentWidth += addedWidth;
      }
    }
    if (current.isNotEmpty) rows.add(current);
    return rows;
  }

  /// Width reserved for a vertical (left/right) legend, or 0 if none.
  static double reservedWidth(ApexOptions options) {
    if (!_shouldShow(options)) return 0;
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
    if (!_shouldShow(options)) return;
    final pos = options.legend.position;
    final names = _names(options);

    final labeller = TextDrawer(
        color: _textColor, fontFamily: options.fontFamily, fontSize: 12);

    switch (pos) {
      case ApexLegendPosition.bottom:
        _paintHorizontal(canvas, canvasSize, options, names, labeller,
            canvasSize.height - 18);
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
    // top is where a SINGLE-row legend would draw (the anchor callers have
    // always passed: canvasSize.height - 18 for bottom, 6 for top). Multiple
    // rows stack from that same anchor — bottom grows upward so the last row
    // stays put where row 0 used to be, top grows downward — so a one-row
    // legend paints at the exact same pixel it always has (goldens unaffected).
    final rows = _wrapRows(names, labeller, size.width);
    final bool anchorsAtBottom = top > size.height / 2;

    for (int r = 0; r < rows.length; r++) {
      final rowTop = anchorsAtBottom
          ? top - (rows.length - 1 - r) * 26
          : top + r * 26;
      _paintRow(canvas, size, options, names, rows[r], labeller, rowTop);
    }
  }

  static void _paintRow(
    Canvas canvas,
    Size size,
    ApexOptions options,
    List<String> names,
    List<int> indices,
    TextDrawer labeller,
    double top,
  ) {
    double total = 0;
    final widths = <double>[];
    for (final i in indices) {
      final w = _markerSize + _markerGap + labeller.measure(names[i]).width;
      widths.add(w);
      total += w + _itemGap;
    }
    total -= _itemGap;

    double x = (size.width - total) / 2;
    final double markerY = top + 6;
    for (int j = 0; j < indices.length; j++) {
      final i = indices[j];
      _marker(canvas, Offset(x, markerY), _colorFor(options, i));
      labeller.draw(
        canvas,
        names[i],
        Offset(x + _markerSize + _markerGap, top),
        anchor: TextAnchor.start,
      );
      x += widths[j] + _itemGap;
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
    final rect =
        Rect.fromLTWH(topLeft.dx, topLeft.dy, _markerSize, _markerSize);
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
