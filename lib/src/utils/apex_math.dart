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

  /// Port of `Utils.mod(a, b, p = 7)` (Utils.js line ~422): `(a % b) / big`.
  ///
  /// `big = 10^(p - floor(log10(max(a, b))))` rescales the operands to ~`p`
  /// significant digits before integer math — bounding the scaled integers so
  /// FP-dirty inputs (e.g. `28.945454547454545`) don't blow up to 10^15-scale
  /// integers. This mirrors ApexCharts exactly; using the raw decimal count
  /// instead caused multi-second stalls on deep zoom (autoScaleYaxis recompute).
  static num mod(num a, num b, {int p = 7}) {
    final num maxAb = math.max(a, b);
    final num big = math.pow(10, p - ApexMath.log10(maxAb).floor());
    final int ia = (a.abs() * big).round();
    final int ib = (b.abs() * big).round();
    return (ia % ib) / big;
  }

  /// Port of `Utils.getGCD(a, b, p = 7)` (Utils.js line ~392): greatest common
  /// divisor for floating-point inputs.
  ///
  /// Scales both operands to ~`p` significant digits via
  /// `big = 10^(p - floor(log10(max(a, b))))` before the Euclidean loop. The
  /// significant-digit cap (not the raw decimal-place count) is essential: it
  /// keeps the scaled integers small (~10^p) so the GCD — and the tick loop
  /// that consumes its result — stay fast even for values with many noisy
  /// decimals. Without it, deep zoom froze the chart for seconds per frame.
  static num getGCD(num a, num b, {int p = 7}) {
    final num maxAb = math.max(a, b);
    final num big = math.pow(10, p - ApexMath.log10(maxAb).floor());

    int ia = (a.abs() * big).round();
    int ib = (b.abs() * big).round();

    while (ib != 0) {
      final int t = ib;
      ib = ia % ib;
      ia = t;
    }
    return ia / big;
  }

  /// Port of `Utils.roundToBase` / `Math.round(a*factor)` helper used across
  /// the codebase to round `value` to `places` decimals.
  static num roundToNDecimals(num value, int places) {
    final num factor = math.pow(10, places);
    return (value * factor).round() / factor;
  }

  /// log base 10, matching `Math.log10`.
  static double log10(num x) => math.log(x) / math.ln10;
}
