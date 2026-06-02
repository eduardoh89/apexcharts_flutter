import 'package:apex_dart/apex_dart.dart';
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
