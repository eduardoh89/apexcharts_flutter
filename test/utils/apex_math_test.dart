import 'package:apexcharts_flutter/apexcharts_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApexMath.isNumber', () {
    test('accepts finite numbers', () {
      expect(ApexMath.isNumber(0), isTrue);
      expect(ApexMath.isNumber(3.14), isTrue);
      expect(ApexMath.isNumber(-7), isTrue);
    });
    test('rejects NaN, infinity and non-numbers', () {
      expect(ApexMath.isNumber(double.nan), isFalse);
      expect(ApexMath.isNumber(double.infinity), isFalse);
      expect(ApexMath.isNumber('5'), isFalse);
      expect(ApexMath.isNumber(null), isFalse);
    });
  });

  group('ApexMath.getGCD', () {
    test('integer gcd', () {
      expect(ApexMath.getGCD(12, 8), 4);
      expect(ApexMath.getGCD(100, 25), 25);
    });
    test('decimal gcd via scaling', () {
      expect(ApexMath.getGCD(0.5, 0.25), closeTo(0.25, 1e-9));
    });
    test('caps precision to ~7 significant digits (perf regression)', () {
      // FP-dirty operands (many noisy decimals) must NOT scale up to
      // 10^15-size integers — that made the Euclidean loop and the downstream
      // niceScale tick loop crawl for seconds, freezing the chart on deep zoom.
      // ApexCharts' getGCD(a, b, p = 7) bounds the scaled integers; verify the
      // call returns quickly and finitely.
      final sw = Stopwatch()..start();
      final g = ApexMath.getGCD(28.340000002, 28.945454547454545);
      sw.stop();
      expect(g.isFinite, isTrue);
      expect(g >= 0, isTrue);
      expect(sw.elapsedMilliseconds, lessThan(50));
    });
  });

  group('ApexMath.mod', () {
    test('matches integer modulo', () {
      expect(ApexMath.mod(10, 3), closeTo(1, 1e-9));
    });
    test('handles decimals without float drift', () {
      expect(ApexMath.mod(0.3, 0.1), closeTo(0, 1e-9));
    });
  });

  group('ApexMath.log10', () {
    test('powers of ten', () {
      expect(ApexMath.log10(1000), closeTo(3, 1e-9));
      expect(ApexMath.log10(1), closeTo(0, 1e-9));
    });
  });
}
