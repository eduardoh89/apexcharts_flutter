import 'package:apexcharts_flutter/apexcharts_flutter.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final labeller = TextDrawer();

  group('CartesianLayout.resolveCategoryLabels', () {
    test('short labels in a wide plot: no rotation, no thinning', () {
      final result = CartesianLayout.resolveCategoryLabels(
        categories: const ['A', 'B', 'C'],
        pointCount: 3,
        plotWidth: 900,
        labeller: labeller,
      );
      expect(result.rotate, isFalse);
      expect(result.step, 1);
      expect(result.extraBottomGutter, 0);
    });

    test('zero points never rotates (no crash on an empty chart)', () {
      final result = CartesianLayout.resolveCategoryLabels(
        categories: const [],
        pointCount: 0,
        plotWidth: 300,
        labeller: labeller,
      );
      expect(result.rotate, isFalse);
      expect(result.step, 1);
      expect(result.extraBottomGutter, 0);
    });

    test('long labels in a narrow plot rotate and reserve extra gutter height', () {
      final result = CartesianLayout.resolveCategoryLabels(
        categories: const ['Enero', 'Febrero', 'Marzo', 'Abril'],
        pointCount: 4,
        plotWidth: 120, // 30px/slot — narrower than any of these labels
        labeller: labeller,
      );
      expect(result.rotate, isTrue);
      expect(result.extraBottomGutter, greaterThan(0));
    });

    // Reproduces the reported bug: 10 real category names from a Japón
    // parking-fee-by-area chart, several long enough ("Patagua Ventas",
    // "Funcionarios Parking") that even a -45° rotation doesn't give each
    // its own slot in a normal dashboard-card width — before this fix, all
    // 10 were drawn anyway and visibly crossed each other.
    test('many long real category names: rotates AND thins to avoid overlap', () {
      const categories = [
        'ESP Ventas',
        'Patagua Ventas',
        'ESO Ventas',
        'Pehuén Ventas',
        'ESP Parking',
        'Patagua Parking',
        'ESO Parking',
        'Pehuén Parking',
        'Parking Patagua',
        'Funcionarios Parking',
      ];
      final result = CartesianLayout.resolveCategoryLabels(
        categories: categories,
        pointCount: categories.length,
        plotWidth: 480, // a typical narrow dashboard-card chart width
        labeller: labeller,
      );

      expect(result.rotate, isTrue);
      expect(result.step, greaterThan(1));
      final visible = List.generate(categories.length, (i) => i)
          .where((i) => i % result.step == 0)
          .length;
      expect(visible, lessThan(categories.length));
    });

    test('the extra bottom gutter is capped, even for a pathologically long label', () {
      final result = CartesianLayout.resolveCategoryLabels(
        categories: const [
          'Un nombre de categoría extremadamente largo que nunca debería aparecer',
        ],
        pointCount: 1,
        plotWidth: 40,
        labeller: labeller,
      );
      expect(result.rotate, isTrue);
      expect(result.extraBottomGutter, lessThanOrEqualTo(70));
    });
  });

  group('CartesianLayout.compute — dynamic bottom gutter', () {
    test('reserves more bottom space when category labels need to rotate', () {
      ApexOptions barWith(List<String> categories) => ApexOptions.fromJson({
            'chart': {'type': 'bar'},
            'series': [
              {
                'name': 'A',
                'data': [1, 2, 3],
              },
            ],
            'xaxis': {'categories': categories},
          });

      const size = Size(320, 240);
      final shortLayout =
          CartesianLayout.compute(barWith(const ['A', 'B', 'C']), size);
      final longLayout = CartesianLayout.compute(
        barWith(const [
          'Categoría número uno',
          'Categoría número dos',
          'Categoría número tres',
        ]),
        size,
      );

      expect(shortLayout.xLabelsRotated, isFalse);
      expect(longLayout.xLabelsRotated, isTrue);
      // A taller reserved gutter means a SMALLER plotRect.bottom (the plot
      // area shrinks to make room) — this is exactly what stops the rotated
      // labels from painting over whatever sits below the chart.
      expect(
        longLayout.plotRect.bottom,
        lessThan(shortLayout.plotRect.bottom),
      );
    });

    // Reproduces a second bug found live in the Revia dashboard: the bottom
    // gutter grew correctly for rotated labels, but the x-axis title's own
    // offset from plotRect.bottom was still a flat +26 (GridRenderer.
    // _paintAxisTitles) — the plot area shrank to make room, but the title
    // never moved down into that new room, so it kept landing exactly where
    // the now-longer rotated labels reach. xLabelsExtraGutter is what lets
    // the title offset grow by the same amount instead of staying flat.
    test('exposes how much extra room rotated labels need, for the title offset to add', () {
      final options = ApexOptions.fromJson({
        'chart': {'type': 'bar'},
        'series': [
          {
            'name': 'A',
            'data': [1, 2, 3],
          },
        ],
        'xaxis': {
          'categories': ['Categoría número uno', 'Categoría número dos', 'Categoría número tres'],
        },
      });
      final layout = CartesianLayout.compute(options, const Size(320, 240));

      expect(layout.xLabelsRotated, isTrue);
      expect(layout.xLabelsExtraGutter, greaterThan(0));

      // Must independently match what resolveCategoryLabels itself would
      // compute for the same inputs — this is what actually guarantees the
      // title offset and the reserved gutter never drift apart.
      final expected = CartesianLayout.resolveCategoryLabels(
        categories: const [
          'Categoría número uno',
          'Categoría número dos',
          'Categoría número tres',
        ],
        pointCount: 3,
        plotWidth: layout.plotRect.width,
        labeller: labeller,
      );
      expect(layout.xLabelsExtraGutter, expected.extraBottomGutter);
    });

    test('a short-label chart keeps xLabelsExtraGutter at 0 (title offset unchanged)', () {
      final options = ApexOptions.fromJson({
        'chart': {'type': 'bar'},
        'series': [
          {
            'name': 'A',
            'data': [1, 2, 3],
          },
        ],
        'xaxis': {
          'categories': ['A', 'B', 'C'],
        },
      });
      final layout = CartesianLayout.compute(options, const Size(320, 240));
      expect(layout.xLabelsRotated, isFalse);
      expect(layout.xLabelsExtraGutter, 0);
    });

    test('a datetime axis never rotates, however long the formatted labels get', () {
      final options = ApexOptions.fromJson({
        'chart': {'type': 'line'},
        'series': [
          {
            'name': 'A',
            'data': [
              [1704067200000, 10],
              [1704153600000, 20],
            ],
          },
        ],
        'xaxis': {'type': 'datetime'},
      });
      final layout = CartesianLayout.compute(options, const Size(150, 200));
      expect(layout.xLabelsRotated, isFalse);
      expect(layout.xLabelStep, 1);
    });
  });
}
