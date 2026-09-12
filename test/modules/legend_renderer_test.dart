import 'package:apexcharts_flutter/apexcharts_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Reproduces the reported bug: a bottom-position legend for the Japón
  // payment-types donut ("Payment", "Manual Pay", "Repayment", "Out in
  // Service Time", "Payment Cancel") painted past the edge of a narrow
  // dashboard card instead of wrapping, bleeding into the neighboring card.
  final japonLabels = [
    'Payment',
    'Manual Pay',
    'Repayment',
    'Out in Service Time',
    'Payment Cancel',
  ];

  ApexOptions donutWithLabels(List<String> labels) => ApexOptions.fromJson({
        'chart': {'type': 'donut'},
        'series': List.filled(labels.length, 20),
        'labels': labels,
        'legend': {'position': 'bottom'},
      });

  group('LegendRenderer.reservedHeight — wraps when items do not fit', () {
    test('narrow width (dashboard card): wraps to more than one row', () {
      final options = donutWithLabels(japonLabels);
      final h = LegendRenderer.reservedHeight(options, 320);
      expect(h, greaterThan(26));
      // Each row is a fixed 26px band, so the reserved height is always an
      // exact multiple of it.
      expect(h % 26, closeTo(0, 1e-9));
    });

    test('wide width: the same legend fits on a single row', () {
      final options = donutWithLabels(japonLabels);
      final h = LegendRenderer.reservedHeight(options, 900);
      expect(h, 26);
    });

    test('single-row case returns exactly 26 (unchanged from before wrapping existed)', () {
      final options = donutWithLabels(['A', 'B']);
      expect(LegendRenderer.reservedHeight(options, 200), 26);
    });

    test('no legend to show (position none) reserves nothing regardless of width', () {
      final options = ApexOptions.fromJson({
        'chart': {'type': 'donut'},
        'series': [1, 1],
        'labels': ['A', 'B'],
        'legend': {'show': false},
      });
      expect(LegendRenderer.reservedHeight(options, 50), 0);
    });

    test('left/right positioned legend never reserves height, at any width', () {
      final options = ApexOptions.fromJson({
        'chart': {'type': 'donut'},
        'series': [1, 1],
        'labels': ['A', 'B'],
        'legend': {'position': 'right'},
      });
      expect(LegendRenderer.reservedHeight(options, 10), 0);
    });

    test('a single item wider than maxWidth still gets its own row, not zero rows', () {
      // Degenerate case: maxWidth smaller than even one label. Must not
      // divide-by-zero, infinite-loop, or drop the item entirely.
      final options = donutWithLabels(['A very very long category name']);
      expect(LegendRenderer.reservedHeight(options, 5), 26);
    });

    test('more rows as the width shrinks further (monotonic, never fewer)', () {
      final options = donutWithLabels(japonLabels);
      final wide = LegendRenderer.reservedHeight(options, 900);
      final narrow = LegendRenderer.reservedHeight(options, 320);
      final tiny = LegendRenderer.reservedHeight(options, 150);
      expect(narrow, greaterThanOrEqualTo(wide));
      expect(tiny, greaterThanOrEqualTo(narrow));
    });
  });
}
