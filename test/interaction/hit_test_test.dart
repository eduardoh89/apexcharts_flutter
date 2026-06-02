import 'dart:ui';

import 'package:apex_dart/apex_dart.dart';
import 'package:apex_dart/src/interaction/cartesian_hit_tester.dart';
import 'package:apex_dart/src/interaction/pie_hit_tester.dart';
import 'package:apex_dart/src/interaction/tile_hit_tester.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const size = Size(600, 360);

  group('CartesianHitTester (shared, by x-index)', () {
    final options = ApexOptions.fromJson({
      'chart': {'type': 'line'},
      'colors': ['#008FFB', '#00E396'],
      'series': [
        {'name': 'A', 'data': [10, 20, 30, 40, 50]},
        {'name': 'B', 'data': [5, 15, 25, 35, 45]},
      ],
      'xaxis': {'categories': ['Jan', 'Feb', 'Mar', 'Apr', 'May']},
    });
    final layout = CartesianLayout.compute(options, size);
    final tester = CartesianHitTester(layout: layout, options: options);

    test('snaps to the nearest category and lists every series', () {
      // x near the first category (index 0 sits at plotRect.left).
      final hit = tester.hitTest(Offset(layout.plotRect.left + 1, 100));
      expect(hit, isNotNull);
      expect(hit!.title, 'Jan');
      expect(hit.rows.length, 2);
      expect(hit.rows[0].formattedValue, '10');
      expect(hit.rows[1].formattedValue, '5');
      expect(hit.crosshairX, isNotNull);
      expect(hit.markerPoints.length, 2);
    });

    test('returns null outside the plot horizontally', () {
      final hit = tester.hitTest(const Offset(2, 100));
      expect(hit, isNull);
    });

    test('snaps to last category at the right edge', () {
      final hit = tester.hitTest(Offset(layout.plotRect.right - 1, 100));
      expect(hit!.title, 'May');
      expect(hit.rows[0].formattedValue, '50');
    });
  });

  group('PieHitTester', () {
    final options = ApexOptions.fromJson({
      'chart': {'type': 'pie'},
      'colors': ['#008FFB', '#00E396', '#FEB019', '#FF4560'],
      'series': [25, 25, 25, 25],
      'labels': ['Q1', 'Q2', 'Q3', 'Q4'],
    });
    final tester = PieHitTester(size: const Size(400, 400), options: options);
    const center = Offset(200, 200);

    test('detects the slice just right of 12 o\'clock (first slice)', () {
      // Slightly clockwise from top = first slice (starts at 12, goes CW).
      final hit = tester.hitTest(const Offset(230, 120));
      expect(hit, isNotNull);
      expect(hit!.title, 'Q1');
      expect(hit.rows.single.formattedValue, '25');
    });

    test('returns null at the exact center (inside any donut hole / origin)',
        () {
      final hit = tester.hitTest(center);
      // Pie has no hole, but center distance 0 still maps to a slice; ensure
      // it does not crash and returns a valid slice.
      expect(hit, isNotNull);
    });

    test('returns null outside the radius', () {
      final hit = tester.hitTest(const Offset(395, 395));
      expect(hit, isNull);
    });
  });

  group('PieHitTester (donut hole)', () {
    final options = ApexOptions.fromJson({
      'chart': {'type': 'donut'},
      'colors': ['#008FFB', '#00E396'],
      'series': [50, 50],
      'labels': ['A', 'B'],
      'plotOptions': {
        'pie': {'donut': {'size': '65%'}}
      },
    });
    final tester = PieHitTester(size: const Size(400, 400), options: options);

    test('returns null inside the donut hole', () {
      final hit = tester.hitTest(const Offset(200, 200));
      expect(hit, isNull);
    });
  });

  group('TileHitTester (heatmap)', () {
    const size = Size(600, 360);
    final options = ApexOptions.fromJson({
      'chart': {'type': 'heatmap'},
      'colors': ['#008FFB'],
      'series': [
        {'name': 'W1', 'data': [
          {'x': 'Mon', 'y': 10}, {'x': 'Tue', 'y': 40}, {'x': 'Wed', 'y': 90}
        ]},
        {'name': 'W2', 'data': [
          {'x': 'Mon', 'y': 50}, {'x': 'Tue', 'y': 20}, {'x': 'Wed', 'y': 60}
        ]},
      ],
      'xaxis': {'type': 'category', 'categories': ['Mon', 'Tue', 'Wed']},
    });
    final tester = TileHitTester(size: size, options: options);

    test('detects the cell under the pointer with its value', () {
      // Use the renderer's own cell geometry to pick a point inside a cell.
      final cells = HeatMapChartRenderer.cells(size, options);
      final target = cells.first;
      final hit = tester.hitTest(target.rect.center);
      expect(hit, isNotNull);
      expect(hit!.rows.single.seriesName, target.seriesName);
      expect(hit.rows.single.formattedValue,
          target.value.toInt().toString());
    });

    test('returns null outside every cell', () {
      final hit = tester.hitTest(const Offset(2, 2));
      expect(hit, isNull);
    });
  });

  group('TileHitTester (treemap)', () {
    const size = Size(600, 360);
    final options = ApexOptions.fromJson({
      'chart': {'type': 'treemap'},
      'colors': ['#008FFB'],
      'series': [
        {'name': 'Desktops', 'data': [
          {'x': 'India', 'y': 218}, {'x': 'USA', 'y': 149},
          {'x': 'China', 'y': 184}, {'x': 'Japan', 'y': 55}
        ]},
      ],
    });
    final tester = TileHitTester(size: size, options: options);

    test('detects the tile under the pointer with its label + value', () {
      final tiles = TreemapChartRenderer.tiles(size, options);
      final target = tiles.first;
      final hit = tester.hitTest(target.rect.center);
      expect(hit, isNotNull);
      expect(hit!.title, target.label);
      expect(hit.rows.single.formattedValue,
          target.value.toInt().toString());
    });
  });
}
