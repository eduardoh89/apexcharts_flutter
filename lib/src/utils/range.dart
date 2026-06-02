import 'dart:math' as math;

import 'apex_math.dart';

/// Result of a scale computation: the tick values plus the nice min/max
/// that bound them. Mirrors the `{result, niceMin, niceMax}` object returned
/// by ApexCharts' `Scales.niceScale()` / `linearScale()`.
class ScaleResult {
  const ScaleResult({
    required this.result,
    required this.niceMin,
    required this.niceMax,
  });

  /// Ordered tick values from [niceMin] to [niceMax].
  final List<num> result;
  final num niceMin;
  final num niceMax;

  int get tickCount => result.isEmpty ? 0 : result.length - 1;

  @override
  String toString() =>
      'ScaleResult(min: $niceMin, max: $niceMax, ticks: $result)';
}

/// Port of the axis-scaling algorithm from ApexCharts v4.7.0
/// `src/modules/Scales.js`.
///
/// ApexCharts' implementation is tightly coupled to the chart's global state
/// (`w.globals`, multi-axis bookkeeping, horizontal-bar special cases, SVG
/// pixel dimensions, user min/max/stepSize/tickAmount overrides). For a
/// decoupled engine we extract the *pure math* and expose the ApexCharts
/// "globals" that actually influence the result as explicit parameters with
/// the same defaults the library uses.
class NiceScale {
  const NiceScale._();

  /// Magic constants copied verbatim from `settings/Globals.js`.
  ///
  /// `niceScaleAllowedMagMsd[a][b]` maps the most-significant-digit of a raw
  /// nice step to an allowed value, indexed by whether the series is all
  /// integers (row 0) or contains floats (row 1).
  static const List<List<int>> _allowedMagMsd = [
    [1, 1, 2, 5, 5, 5, 10, 10, 10, 10, 10],
    [1, 1, 2, 5, 5, 5, 10, 10, 10, 10, 10],
  ];

  /// Default tick counts indexed by `min(round(maxTicks/2), len-1)`.
  static const List<int> _defaultTicks = [
    1, 2, 4, 4, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, //
    6, 6, 12, 12, 12, 12, 12, 12, 12, 12, 12, 24,
  ];

  /// Faithful port of `Scales.niceScale(yMin, yMax)` for the common,
  /// non-overridden path (no user-defined min/max/stepSize/tickAmount, single
  /// y-axis, vertical orientation).
  ///
  /// * [yMin], [yMax] — raw data extent.
  /// * [maxTicks] — the upper bound on ticks ApexCharts derives from the SVG
  ///   height: `max((svgHeight - 100) / 15, 2)`. Pass that value here; for a
  ///   pure computation a default of 10 reproduces the library fallback when
  ///   the dimension is not a number.
  /// * [valueDecimals] — `gl.yValueDecimal`; 0 selects the integer MSD row.
  static ScaleResult niceScale(
    num yMin,
    num yMax, {
    double maxTicks = 10,
    int valueDecimals = 0,
  }) {
    const double jsPrecision = 1e-11;

    if (!ApexMath.isNumber(maxTicks)) maxTicks = 10;

    // Default tick guess based on maxTicks.
    int ticks = _defaultTicks[math.min(
      (maxTicks / 2).round(),
      _defaultTicks.length - 1,
    )];

    // Degenerate ranges.
    if (!ApexMath.isNumber(yMin) && !ApexMath.isNumber(yMax)) {
      yMin = 0;
      yMax = yMin + ticks;
    }

    if (yMin > yMax) {
      final num tmp = yMax;
      yMax = yMin;
      yMin = tmp;
    } else if (yMin == yMax) {
      yMin = yMin == 0 ? 0 : yMin - 1;
      yMax = yMax == 0 ? 2 : yMax + 1;
    }

    if (ticks < 1) ticks = 1;
    int tiks = ticks;

    num range = (yMax - yMin).abs();

    // Snap min/max to zero when close (proximityRatio = 0.15).
    const double proximityRatio = 0.15;
    bool gotMin = false;
    bool gotMax = false;
    if (yMin > 0 && yMin / range < proximityRatio) {
      yMin = 0;
      gotMin = true;
    }
    if (yMax < 0 && -yMax / range < proximityRatio) {
      yMax = 0;
      gotMax = true;
    }
    range = (yMax - yMin).abs();

    // Pretty step value.
    num stepSize = range / tiks;
    num niceStep = stepSize;
    final int mag = ApexMath.log10(niceStep).floor();
    final num magPow = math.pow(10, mag);
    int magMsd = (niceStep / magPow).ceil();
    magMsd = _allowedMagMsd[valueDecimals == 0 ? 0 : 1]
        [magMsd.clamp(0, _allowedMagMsd[0].length - 1)];
    niceStep = magMsd * magPow;
    stepSize = niceStep;

    // Common path: no user min/max → snap range to ticks.
    if (!gotMin && !gotMax) {
      yMin = stepSize * (yMin / stepSize).floor();
      yMax = stepSize * (yMax / stepSize).ceil();
    } else if (gotMax) {
      final num yMinPrev = yMin;
      yMin = stepSize * (yMin / stepSize).floor();
      if ((yMax - yMin).abs() / ApexMath.getGCD(range, stepSize) > maxTicks) {
        yMin = yMax - stepSize * ticks;
        yMin += stepSize * ((yMinPrev - yMin) / stepSize).floor();
      }
    } else if (gotMin) {
      final num yMaxPrev = yMax;
      yMax = stepSize * (yMax / stepSize).ceil();
      if ((yMax - yMin).abs() / ApexMath.getGCD(range, stepSize) > maxTicks) {
        yMax = yMin + stepSize * ticks;
        yMax += stepSize * ((yMaxPrev - yMax) / stepSize).ceil();
      }
    }

    range = (yMax - yMin).abs();
    stepSize = ApexMath.getGCD(range, stepSize);
    tiks = (range / stepSize).round();

    // Shrinkwrap ticks to the range (no user tickAmount/min/max).
    tiks = ((range - jsPrecision) / (stepSize + jsPrecision)).ceil();
    if (tiks > 16 && _primeFactors(tiks).length < 2) {
      tiks++;
    }

    // Reduce ticks nicely if they exceed maxTicks.
    if (tiks > maxTicks) {
      final List<int> pf = _primeFactors(tiks);
      final int last = pf.length - 1;
      int tt = tiks;
      reduceLoop:
      for (int xFactors = 0; xFactors < last; xFactors++) {
        for (int lowest = 0; lowest <= last - xFactors; lowest++) {
          final int stop = math.min(lowest + xFactors, last);
          int div = 1;
          for (int next = lowest; next <= stop; next++) {
            div *= pf[next];
          }
          final int t = (tt / div).round();
          if (t < maxTicks) {
            tt = t;
            break reduceLoop;
          }
        }
      }
      stepSize = tt == tiks ? range : range / tt;
      tiks = (range / stepSize).round();
    }

    // Build the tick array.
    final List<num> result = [];
    final num err = stepSize * jsPrecision;
    num val = yMin - stepSize;
    do {
      val += stepSize;
      result.add(ApexMath.roundToNDecimals(val, 7));
    } while (yMax - val > err);

    return ScaleResult(
      result: result,
      niceMin: result.first,
      niceMax: result.last,
    );
  }

  /// Port of `Scales.linearScale()` — evenly spaced ticks without the
  /// "nice number" snapping. Useful for axes that must honour an exact range.
  static ScaleResult linearScale(
    num yMin,
    num yMax, {
    int ticks = 10,
    num? step,
  }) {
    final num range = (yMax - yMin).abs();
    if (yMin == yMax) {
      return ScaleResult(result: [yMin], niceMin: yMin, niceMax: yMin);
    }

    num s = step ?? range / ticks;
    // Math.round((step + EPSILON) * 100) / 100
    s = ((s + 2.220446049250313e-16) * 100).round() / 100;

    final List<num> result = [];
    num v = yMin;
    int remaining = ticks;
    while (remaining >= 0) {
      result.add(v);
      v = _preciseAddition(v, s);
      remaining -= 1;
    }

    return ScaleResult(
      result: result,
      niceMin: result.first,
      niceMax: result.last,
    );
  }

  /// Port of `Utils.getPrimeFactors`.
  static List<int> _primeFactors(int n) {
    final List<int> factors = [];
    int divisor = 2;
    while (n >= 2) {
      if (n % divisor == 0) {
        factors.add(divisor);
        n = n ~/ divisor;
      } else {
        divisor++;
      }
    }
    return factors;
  }

  /// Port of `Utils.preciseAddition`: avoids float drift when stepping.
  static num _preciseAddition(num a, num b) {
    final int decA = _decimals(a);
    final int decB = _decimals(b);
    final int dec = math.max(decA, decB);
    final num factor = math.pow(10, dec);
    return ((a * factor).round() + (b * factor).round()) / factor;
  }

  static int _decimals(num value) {
    if (value == value.truncate()) return 0;
    final String s = value.toString();
    final int dot = s.indexOf('.');
    return dot < 0 ? 0 : s.length - dot - 1;
  }
}
