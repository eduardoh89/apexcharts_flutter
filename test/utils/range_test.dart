import 'package:apexcharts_flutter/apexcharts_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NiceScale.niceScale', () {
    test('produces nice round ticks for 0..100', () {
      final r = NiceScale.niceScale(0, 100);
      expect(r.niceMin, 0);
      expect(r.niceMax, greaterThanOrEqualTo(100));
      // Ticks must be evenly spaced.
      final step = r.result[1] - r.result[0];
      for (int i = 1; i < r.result.length; i++) {
        expect((r.result[i] - r.result[i - 1] - step).abs() < 1e-6, isTrue,
            reason: 'uneven step at $i: ${r.result}');
      }
    });

    test('resolves FP-dirty deep-zoom ranges fast (no freeze regression)', () {
      // Repeated zoom with autoScaleYaxis feeds ranges whose bounds carry many
      // noisy decimals (e.g. 28.945454547454545). These previously made a
      // single niceScale call take tens of seconds (getGCD precision blowup),
      // freezing the chart. Each call must now be effectively instant.
      final ranges = <List<num>>[
        [28.340000002, 28.945454547454545],
        [30.45170000000012, 30.46220000000031],
        [12.333333333333334, 12.999999999999996],
        [0.10000000000000009, 0.30000000000000004],
      ];
      for (final r in ranges) {
        final sw = Stopwatch()..start();
        final s = NiceScale.niceScale(r[0], r[1], maxTicks: 18);
        sw.stop();
        expect(sw.elapsedMilliseconds, lessThan(100),
            reason:
                'niceScale(${r[0]}..${r[1]}) took ${sw.elapsedMilliseconds}ms');
        expect(s.result.length, lessThan(1000));
        expect(s.result.length, greaterThanOrEqualTo(2));
      }
    });

    test('snaps a near-zero min down to zero (proximity ratio)', () {
      // yMin/range = 5/100 = 0.05 < 0.15 → snaps to 0.
      final r = NiceScale.niceScale(5, 105);
      expect(r.niceMin, 0);
    });

    test('covers the full data range', () {
      final r = NiceScale.niceScale(3, 47);
      expect(r.niceMin, lessThanOrEqualTo(3));
      expect(r.niceMax, greaterThanOrEqualTo(47));
    });

    test('handles identical min and max without dividing by zero', () {
      final r = NiceScale.niceScale(10, 10);
      expect(r.result.isNotEmpty, isTrue);
      expect(r.niceMax, greaterThan(r.niceMin));
    });

    test('respects maxTicks ceiling', () {
      final r = NiceScale.niceScale(0, 1000, maxTicks: 5);
      expect(r.tickCount, lessThanOrEqualTo(6));
    });

    test('handles negative ranges', () {
      final r = NiceScale.niceScale(-50, -10);
      expect(r.niceMin, lessThanOrEqualTo(-50));
      expect(r.niceMax, greaterThanOrEqualTo(-10));
    });
  });

  group('NiceScale.linearScale', () {
    test('returns single value when min == max', () {
      final r = NiceScale.linearScale(5, 5);
      expect(r.result, [5]);
    });

    test('produces ticks+1 entries', () {
      final r = NiceScale.linearScale(0, 10, ticks: 5);
      expect(r.result.length, 6);
      expect(r.niceMin, 0);
    });
  });

  group('NiceScale.logarithmicScale', () {
    test('powers of the base for a geometric range (1..1e6)', () {
      final r = NiceScale.logarithmicScale(1, 1000000);
      expect(r.niceMin, 1);
      expect(r.niceMax, 1000000);
      // 6 log decades + final tick at yMax -> 7 ticks: 1,10,...,1e6.
      expect(r.result.length, 7);
      expect(r.result.first, closeTo(1, 1e-6));
      expect(r.result[1], closeTo(10, 1e-6));
      expect(r.result.last, closeTo(1000000, 1e-3));
    });

    test('clamps non-positive bounds to the base', () {
      final r = NiceScale.logarithmicScale(0, 100);
      expect(r.niceMin, greaterThan(0));
      expect(r.niceMax, 100);
    });
  });
}
