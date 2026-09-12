import 'dart:ui';

import 'package:apexcharts_flutter/apexcharts_flutter.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HeatMapChartRenderer.cells — low-value shading floor', () {
    // Reproduces the reported bug: "Monto Vendido Por Día de la Semana y
    // Hora - DBNet" — a cell worth real money ($52,250, ~3.5% of the
    // chart's ~$1.5M max) rendered visually indistinguishable from an
    // empty/no-data cell because real ApexCharts' non-negative shading
    // path never applies shadeIntensity, letting colorShadePercent reach
    // 1.0 (pure white). REVIA intentionally deviates from upstream here.
    ApexOptions optionsWith({
      required List<num> values,
      double shadeIntensity = 0.85,
    }) =>
        ApexOptions.fromJson({
          'chart': {'type': 'heatmap'},
          'colors': ['#008DEC'],
          'plotOptions': {
            'heatmap': {
              'enableShades': true,
              'shadeIntensity': shadeIntensity,
            },
          },
          'series': [
            {
              'name': 'Fila',
              'data': [for (final v in values) v],
            },
          ],
        });

    test('a low-but-real value keeps a visible tint, not washed out', () {
      final options = optionsWith(values: [52250, 1500000]);
      final cells = HeatMapChartRenderer.cells(const Size(320, 60), options);

      final lowValueCell = cells.firstWhere((c) => c.value == 52250);
      // Pre-fix this cell shades to ~RGB(246,251,254) — g ≈ 0.984, close
      // enough to pure white (1.0) to read as empty. Post-fix it lands at
      // ~RGB(209,235,252) — g ≈ 0.922, clearly a tinted cell. 0.96 sits
      // strictly between the two, so this only passes with the floor.
      expect(lowValueCell.color.g, lessThan(0.96));
    });

    test('the max value in the chart keeps the full base color', () {
      // minY must be 0 so the max value's percent hits exactly 100%
      // (otherwise |max|+|min| inflates the denominator and even the peak
      // cell falls slightly short of full saturation — a property of the
      // real ApexCharts formula itself, not of this fix).
      final options = optionsWith(values: [0, 52250, 1500000]);
      final cells = HeatMapChartRenderer.cells(const Size(320, 60), options);

      final maxValueCell = cells.firstWhere((c) => c.value == 1500000);
      expect(maxValueCell.color, const Color(0xFF008DEC));
    });

    test('a zero-value cell is lighter than a real low-value cell', () {
      final options = optionsWith(values: [0, 52250, 1500000]);
      final cells = HeatMapChartRenderer.cells(const Size(320, 60), options);

      final zeroCell = cells.firstWhere((c) => c.value == 0);
      final lowValueCell = cells.firstWhere((c) => c.value == 52250);
      // Both keep a floor of visible color, but zero is still the lightest
      // — the floor removes "invisible", it doesn't erase the gradient.
      expect(zeroCell.color.g, greaterThan(lowValueCell.color.g));
    });
  });
}
