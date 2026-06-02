import 'dart:math' as math;
import 'dart:ui';

import '../options/apex_options.dart';
import '../svg/text_drawer.dart';
import '../utils/apex_color.dart';

/// Renders treemap charts, ported from ApexCharts v4.7.0 `src/charts/Treemap.js`
/// + the squarified layout in `src/libs/Treemap-squared.js` (Bruls/Huizing/
/// van Wijk squarified treemaps) and the cell color logic in
/// `charts/common/treemap/Helpers.js`.
///
/// Each data point `{ x: label, y: value }` becomes a rectangle sized by value;
/// the squarify algorithm packs them into near-square tiles. Cell color shades
/// the palette color by the value percentile (treemap uses shadeIntensity*1.25).
/// A single laid-out treemap tile, shared by the renderer and the hit-tester.
class TreemapTile {
  const TreemapTile({
    required this.rect,
    required this.color,
    required this.seriesName,
    required this.label,
    required this.value,
    required this.dataPointIndex,
  });

  final Rect rect;
  final Color color;
  final String seriesName;
  final String label;
  final double value;
  final int dataPointIndex;
}

class TreemapChartRenderer {
  const TreemapChartRenderer._();

  static const double _topPadding = 10;

  /// Computes the laid-out tiles (geometry + color + data) for [options] within
  /// [size]. Shared by [paint] and the hit-tester so both agree exactly.
  static List<TreemapTile> tiles(Size size, ApexOptions options) {
    final series = options.series;
    if (series.isEmpty) return const [];
    final s = series.first;
    final points = s.points.where((p) => !p.isNull).toList();
    if (points.isEmpty) return const [];

    final plot = Rect.fromLTRB(0, _topPadding, size.width, size.height);
    final values = points.map((p) => p.y.abs()).toList();
    final rects = _squarify(values, plot);

    double minY = double.infinity, maxY = -double.infinity;
    for (final p in points) {
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    final double total =
        (maxY.abs() + minY.abs()) == 0 ? -0.000001 : maxY.abs() + minY.abs();
    final double shadeIntensity = options.treemap.shadeIntensity;
    final bool distributed = options.treemap.distributed;

    final out = <TreemapTile>[];
    for (int i = 0; i < rects.length && i < points.length; i++) {
      final p = points[i];
      final Color base = distributed
          ? options.colors[i % options.colors.length]
          : (s.color ?? options.colors.first);
      final Color color = options.treemap.enableShades
          ? _shadeFor(base, 100 * p.y / total, shadeIntensity)
          : base;
      out.add(TreemapTile(
        rect: rects[i],
        color: color,
        seriesName: s.name,
        label: p.label ?? '',
        value: p.y,
        dataPointIndex: i,
      ));
    }
    return out;
  }

  static void paint(Canvas canvas, Size size, ApexOptions options) {
    final laid = tiles(size, options);
    if (laid.isEmpty) return;

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFFFFFFF);

    for (final tile in laid) {
      final r = tile.rect;
      final rrect = RRect.fromRectAndRadius(
        r,
        Radius.circular(options.treemap.borderRadius),
      );
      canvas.drawRRect(rrect, Paint()..color = tile.color..isAntiAlias = true);
      canvas.drawRRect(rrect, strokePaint);

      // Label: tile name centered, drawn when it fits.
      final label = tile.label;
      if (label.isEmpty) continue;
      final double area = r.width * r.height;
      final double fontSize =
          math.min(math.sqrt(area) / math.max(label.length, 1), 14);
      if (fontSize < 6) continue;
      final labeller = TextDrawer(
        color: const Color(0xFFFFFFFF),
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        fontFamily: options.fontFamily,
      );
      final tw = labeller.measure(label).width;
      if (tw > r.width - 4) continue;
      labeller.draw(
        canvas,
        label,
        r.center,
        anchor: TextAnchor.middle,
        verticalCenter: true,
      );
    }
  }

  /// Treemap cell shade (treemap default path of `getShadeColor`):
  /// colorShadePercent = (1 - percent/100) * (shadeIntensity * 1.25).
  static Color _shadeFor(Color base, double percent, double shadeIntensity) {
    final double colorShadePercent =
        (1 - percent / 100) * (shadeIntensity * 1.25);
    return ApexColor.shade(base, colorShadePercent);
  }

  // --- Squarified treemap (port of Treemap-squared.js, single dimension). ---

  static List<Rect> _squarify(List<double> data, Rect bounds) {
    final double area = bounds.width * bounds.height;
    final double sum = data.fold(0.0, (a, b) => a + b);
    if (sum <= 0) return const [];
    final normalized = data.map((d) => d * area / sum).toList();

    final out = <Rect>[];
    _squarifyRec(
      normalized,
      <double>[],
      _Container(bounds.left, bounds.top, bounds.width, bounds.height),
      out,
    );
    return out;
  }

  static void _squarifyRec(
    List<double> data,
    List<double> currentRow,
    _Container container,
    List<Rect> out,
  ) {
    if (data.isEmpty) {
      out.addAll(container.coordinates(currentRow));
      return;
    }
    final double length = container.shortestEdge;
    final double next = data.first;

    if (_improvesRatio(currentRow, next, length)) {
      final row = [...currentRow, next];
      _squarifyRec(data.sublist(1), row, container, out);
    } else {
      final newContainer = container.cutArea(_sum(currentRow));
      out.addAll(container.coordinates(currentRow));
      _squarifyRec(data, <double>[], newContainer, out);
    }
  }

  static bool _improvesRatio(
    List<double> currentRow,
    double nextNode,
    double length,
  ) {
    if (currentRow.isEmpty) return true;
    final newRow = [...currentRow, nextNode];
    final cur = _ratio(currentRow, length);
    final next = _ratio(newRow, length);
    return cur >= next;
  }

  static double _ratio(List<double> row, double length) {
    final double mn = row.reduce(math.min);
    final double mx = row.reduce(math.max);
    final double sum = _sum(row);
    return math.max(
      (length * length * mx) / (sum * sum),
      (sum * sum) / (length * length * mn),
    );
  }

  static double _sum(List<double> arr) => arr.fold(0.0, (a, b) => a + b);
}

/// Container box for the squarify layout (port of `Container`).
class _Container {
  _Container(this.xoffset, this.yoffset, this.width, this.height);
  final double xoffset;
  final double yoffset;
  final double width;
  final double height;

  double get shortestEdge => math.min(width, height);

  List<Rect> coordinates(List<double> row) {
    final coords = <Rect>[];
    double subx = xoffset;
    double suby = yoffset;
    final double rowSum = row.fold(0.0, (a, b) => a + b);
    if (width >= height) {
      final double areaWidth = rowSum / height;
      for (final v in row) {
        coords.add(Rect.fromLTRB(subx, suby, subx + areaWidth, suby + v / areaWidth));
        suby += v / areaWidth;
      }
    } else {
      final double areaHeight = rowSum / width;
      for (final v in row) {
        coords.add(Rect.fromLTRB(subx, suby, subx + v / areaHeight, suby + areaHeight));
        subx += v / areaHeight;
      }
    }
    return coords;
  }

  _Container cutArea(double area) {
    if (width >= height) {
      final double areaWidth = area / height;
      return _Container(xoffset + areaWidth, yoffset, width - areaWidth, height);
    } else {
      final double areaHeight = area / width;
      return _Container(xoffset, yoffset + areaHeight, width, height - areaHeight);
    }
  }
}
