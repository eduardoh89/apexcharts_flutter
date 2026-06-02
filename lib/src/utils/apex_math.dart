import 'dart:math' as math;

/// Faithful port of the numeric helpers in ApexCharts v4.7.0 `src/utils/Utils.js`.
///
/// These are deliberately kept as standalone pure functions so they can be
/// unit-tested in isolation against the JS originals.
class ApexMath {
  const ApexMath._();

  /// Port of `Utils.isNumber`: finite, real number.
  static bool isNumber(Object? value) {
    if (value is num) {
      return !value.isNaN && value.isFinite;
    }
    return false;
  }

  /// Port of `Utils.mod` (line ~425):
  /// `(a % b) / big` where `big` rescales to integer math to avoid FP error.
  ///
  /// The JS implementation multiplies both operands up by a power of ten
  /// derived from the larger number of decimals, does an integer modulo, then
  /// scales back down. We reproduce that exactly.
  static num mod(num a, num b) {
    final int decA = _decimalPlaces(a);
    final int decB = _decimalPlaces(b);
    final int dec = math.max(decA, decB);
    final num big = math.pow(10, dec);
    return ((a * big).round() % (b * big).round()) / big;
  }

  /// Port of `Utils.getGCD` (line ~397): greatest common divisor that works
  /// for floating point inputs by scaling to integers first.
  static num getGCD(num a, num b) {
    final int decA = _decimalPlaces(a);
    final int decB = _decimalPlaces(b);
    final int dec = math.max(decA, decB);
    final num big = math.pow(10, dec);

    int ia = (a * big).round();
    int ib = (b * big).round();

    while (ib != 0) {
      final int t = ib;
      ib = ia % ib;
      ia = t;
    }
    return ia.abs() / big;
  }

  /// Port of `Utils.roundToBase` / `Math.round(a*factor)` helper used across
  /// the codebase to round `value` to `places` decimals.
  static num roundToNDecimals(num value, int places) {
    final num factor = math.pow(10, places);
    return (value * factor).round() / factor;
  }

  /// log base 10, matching `Math.log10`.
  static double log10(num x) => math.log(x) / math.ln10;

  static int _decimalPlaces(num value) {
    if (value == value.truncate()) return 0;
    final String s = value.toString();
    if (s.contains('e') || s.contains('E')) {
      // Scientific notation: derive from exponent.
      final parts = s.toLowerCase().split('e');
      final int exp = int.tryParse(parts[1]) ?? 0;
      final int fracLen =
          parts[0].contains('.') ? parts[0].split('.')[1].length : 0;
      return math.max(0, fracLen - exp);
    }
    final int dot = s.indexOf('.');
    return dot < 0 ? 0 : s.length - dot - 1;
  }
}
