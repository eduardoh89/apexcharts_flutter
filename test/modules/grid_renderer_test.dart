import 'package:apexcharts_flutter/apexcharts_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GridRenderer.numericXTicks', () {
    // Reproduces the reported bug: "Eventos del Diario Europa por hora -
    // 13 de agosto 2026" — an hour-of-day numeric axis (0..23) rendered
    // "0, 3.83, 7.67, 11.50, 15.33, 19.17, 23" (naive evenly-spaced
    // fractions of the exact range) instead of round numbers.
    test('a 0..23 hour-of-day axis lands on round numbers, not fractions', () {
      final ticks = GridRenderer.numericXTicks(
        xMin: 0,
        xMax: 23,
        plotWidth: 600,
      );
      for (final tick in ticks) {
        expect(tick, tick.truncate(), reason: '$tick should be a whole number');
      }
      // The reported fractions must not appear.
      expect(ticks, isNot(contains(closeTo(3.83, 0.01))));
      expect(ticks, isNot(contains(closeTo(7.67, 0.01))));
    });

    test('an explicit tickAmount is honored as the upper bound', () {
      final withDefault = GridRenderer.numericXTicks(
        xMin: 0,
        xMax: 23,
        plotWidth: 600,
      );
      final withTwelve = GridRenderer.numericXTicks(
        xMin: 0,
        xMax: 23,
        plotWidth: 600,
        tickAmount: 12,
      );
      // A tickAmount of 12 is a much looser bound than the density-derived
      // default for a 600px-wide plot — it must not produce FEWER ticks.
      expect(withTwelve.length, greaterThanOrEqualTo(withDefault.length));
    });

    test('a degenerate zero-width range never crashes', () {
      expect(
        () => GridRenderer.numericXTicks(xMin: 5, xMax: 5, plotWidth: 600),
        returnsNormally,
      );
    });

    test('a narrow plot still returns at least 2 ticks', () {
      final ticks = GridRenderer.numericXTicks(
        xMin: 0,
        xMax: 100,
        plotWidth: 50,
      );
      expect(ticks.length, greaterThanOrEqualTo(2));
    });
  });
}
