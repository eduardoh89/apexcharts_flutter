import 'package:apexcharts_flutter/apexcharts_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PieChartRenderer.sliceSweepDegrees', () {
    test('splits 360° proportionally to each value', () {
      final sweeps = PieChartRenderer.sliceSweepDegrees([1, 1, 2]);
      expect(sweeps, [closeTo(90, 1e-9), closeTo(90, 1e-9), closeTo(180, 1e-9)]);
    });

    test('negative values clamp to 0, matching paint()', () {
      final sweeps = PieChartRenderer.sliceSweepDegrees([10, -5, 10]);
      expect(sweeps, [closeTo(180, 1e-9), 0, closeTo(180, 1e-9)]);
    });

    test('all-zero series does not divide by zero', () {
      final sweeps = PieChartRenderer.sliceSweepDegrees([0, 0]);
      expect(sweeps, everyElement(isNot(isNaN)));
    });
  });

  group('PieChartRenderer.labelsToShow', () {
    // Reproduces the reported bug: "Total de ventas por tipo de pago -
    // Japón" (Payment 56.1%, Out in Service Time 43.3%, Manual Pay 0.5%,
    // Repayment 0.1%, Payment Cancel 0.1%) — the three sub-1% slices placed
    // their percentage labels close enough along the arc to overlap.
    const japonPaymentTypes = [561.0, 433.0, 5.0, 1.0, 1.0]; // sums to 1001

    test('hides labels for the tiny slices that were overlapping, default threshold', () {
      final show = PieChartRenderer.labelsToShow(
        japonPaymentTypes,
        10, // ApexOptions default
      );
      expect(show, [true, true, false, false, false]);
    });

    test('threshold 0 shows every label (feature effectively off)', () {
      final show = PieChartRenderer.labelsToShow(japonPaymentTypes, 0);
      expect(show, [true, true, true, true, true]);
    });

    test('boundary slice at exactly the threshold angle is shown (>=, not >)', () {
      // 10% of 360° is exactly 36°, i.e. a 10-degree-wide slice is a value
      // of 10/360 of the total — construct that directly.
      final show = PieChartRenderer.labelsToShow([350, 10], 10);
      expect(show, [true, true]);
    });
  });

  group('ApexOptions.fromJson — dataLabelsMinAngleToShowLabel', () {
    test('defaults to 10 when not specified', () {
      final o = ApexOptions.fromJson({
        'chart': {'type': 'donut'},
        'series': [50, 50],
      });
      expect(o.dataLabelsMinAngleToShowLabel, 10);
    });

    test('reads an explicit override', () {
      final o = ApexOptions.fromJson({
        'chart': {'type': 'pie'},
        'series': [50, 50],
        'dataLabels': {'minAngleToShowLabel': 15},
      });
      expect(o.dataLabelsMinAngleToShowLabel, 15);
    });
  });
}
