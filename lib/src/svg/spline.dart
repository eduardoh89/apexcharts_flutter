import 'dart:math' as math;
import 'dart:ui';

/// Monotone cubic spline, ported from ApexCharts v4.7.0
/// `src/libs/monotone-cubic.js` (itself @yr/monotone-cubic-spline, MIT).
///
/// ApexCharts uses this for `stroke.curve: 'smooth'`. Reproducing it exactly
/// is what makes our smooth lines match ApexCharts pixel-for-pixel rather than
/// using Flutter's generic quadratic smoothing.
class MonotoneSpline {
  const MonotoneSpline._();

  /// Build a [Path] through [points] using monotone cubic interpolation.
  /// Falls back to a straight polyline when there are fewer than 3 points.
  static Path buildPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    if (points.length < 3) {
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      return path;
    }

    final pts = points.map((o) => <double>[o.dx, o.dy]).toList();
    final bezier = _splinePoints(pts);

    // bezier[0] is the start point [x, y]; subsequent entries are either
    // 6-length (full cubic C: c1x,c1y,c2x,c2y,x,y) or 4-length (smooth S:
    // c2x,c2y,x,y) where the first control point is the reflection of the
    // previous one.
    path.moveTo(bezier[0][0], bezier[0][1]);

    double prevC2x = bezier[0][0];
    double prevC2y = bezier[0][1];
    double curX = bezier[0][0];
    double curY = bezier[0][1];

    for (int i = 1; i < bezier.length; i++) {
      final seg = bezier[i];
      double c1x, c1y, c2x, c2y, x, y;
      if (seg.length >= 6) {
        c1x = seg[0];
        c1y = seg[1];
        c2x = seg[2];
        c2y = seg[3];
        x = seg[4];
        y = seg[5];
      } else {
        // 'S' command: reflect previous second control point about current pt.
        c1x = curX * 2 - prevC2x;
        c1y = curY * 2 - prevC2y;
        c2x = seg[0];
        c2y = seg[1];
        x = seg[2];
        y = seg[3];
      }
      path.cubicTo(c1x, c1y, c2x, c2y, x, y);
      prevC2x = c2x;
      prevC2y = c2y;
      curX = x;
      curY = y;
    }
    return path;
  }

  static double _slope(List<double> p0, List<double> p1) {
    return (p1[1] - p0[1]) / (p1[0] - p0[0]);
  }

  static List<double> _finiteDifferences(List<List<double>> points) {
    final m = List<double>.filled(points.length, 0);
    var p0 = points[0];
    var p1 = points[1];
    double d = _slope(p0, p1);
    m[0] = d;
    int i = 1;
    for (final n = points.length - 1; i < n; i++) {
      p0 = p1;
      p1 = points[i + 1];
      final prevD = d;
      d = _slope(p0, p1);
      m[i] = (prevD + d) * 0.5;
    }
    m[i] = d;
    return m;
  }

  static List<List<double>> _tangents(List<List<double>> points) {
    final m = _finiteDifferences(points);
    final n = points.length - 1;
    const double eps = 1e-6;
    final tgts = <List<double>>[];

    for (int i = 0; i < n; i++) {
      final d = _slope(points[i], points[i + 1]);
      if (d.abs() < eps) {
        m[i] = 0;
        m[i + 1] = 0;
      } else {
        final a = m[i] / d;
        final b = m[i + 1] / d;
        var s = a * a + b * b;
        if (s > 9) {
          s = (d * 3) / math.sqrt(s);
          m[i] = s * a;
          m[i + 1] = s * b;
        }
      }
    }

    for (int i = 0; i <= n; i++) {
      final s = (points[math.min(n, i + 1)][0] -
              points[math.max(0, i - 1)][0]) /
          (6 * (1 + m[i] * m[i]));
      tgts.add([_zeroIfNan(s), _zeroIfNan(m[i] * s)]);
    }
    return tgts;
  }

  static List<List<double>> _splinePoints(List<List<double>> points) {
    final tgts = _tangents(points);
    final p = points[1];
    final p0 = points[0];
    final pts = <List<double>>[];
    final t = tgts[1];
    final t0 = tgts[0];

    pts.add(p0);
    pts.add([
      p0[0] + t0[0],
      p0[1] + t0[1],
      p[0] - t[0],
      p[1] - t[1],
      p[0],
      p[1],
    ]);

    for (int i = 2; i < tgts.length; i++) {
      final pi = points[i];
      final ti = tgts[i];
      pts.add([pi[0] - ti[0], pi[1] - ti[1], pi[0], pi[1]]);
    }
    return pts;
  }

  static double _zeroIfNan(double v) => v.isNaN ? 0 : v;
}
