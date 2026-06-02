import 'dart:ui';

import '../charts/heatmap_chart.dart';
import '../charts/treemap_chart.dart';
import '../options/apex_options.dart';
import '../utils/format_value.dart';
import 'chart_hit.dart';

/// Hit-testing for the rectangular tile charts (heatmap and treemap): find the
/// cell/tile under the pointer using the exact same geometry the renderers draw
/// (`HeatMapChartRenderer.cells` / `TreemapChartRenderer.tiles`). ApexCharts
/// shows a tooltip with the cell's label and value on hover.
class TileHitTester {
  TileHitTester({required this.size, required this.options});

  final Size size;
  final ApexOptions options;

  ChartHit? hitTest(Offset local) {
    switch (options.type) {
      case ApexChartType.heatmap:
        return _heatmap(local);
      case ApexChartType.treemap:
        return _treemap(local);
      default:
        return null;
    }
  }

  ChartHit? _heatmap(Offset local) {
    final cells = HeatMapChartRenderer.cells(size, options);
    for (final c in cells) {
      if (c.rect.contains(local)) {
        // ApexCharts heatmap tooltip: "<seriesName>: <value>" with the cell
        // color marker; the heading is the category (column) label.
        return ChartHit(
          title: c.label,
          rows: [
            TooltipSeriesValue(
              color: c.color,
              seriesName: c.seriesName,
              formattedValue: FormatValue.formatted(c.value, options.yFormat),
              highlighted: true,
            ),
          ],
          anchor: c.rect.center,
        );
      }
    }
    return null;
  }

  ChartHit? _treemap(Offset local) {
    final tiles = TreemapChartRenderer.tiles(size, options);
    for (final t in tiles) {
      if (t.rect.contains(local)) {
        // ApexCharts treemap tooltip: the tile label as heading + its value.
        return ChartHit(
          title: t.label,
          rows: [
            TooltipSeriesValue(
              color: t.color,
              seriesName: t.label.isNotEmpty ? t.label : t.seriesName,
              formattedValue: FormatValue.formatted(t.value, options.yFormat),
              highlighted: true,
            ),
          ],
          anchor: t.rect.center,
        );
      }
    }
    return null;
  }
}
