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
