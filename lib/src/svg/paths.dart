import 'dart:ui';

import '../options/apex_options.dart';
import 'spline.dart';

/// SVG-path equivalents for the line/area renderers, ported conceptually from
/// ApexCharts `Line.js` path building. Produces Flutter [Path]s.
class ApexPaths {
  const ApexPaths._();

  /// Build the line path for a series given pixel-space points and the
  /// configured [curve].
  static Path linePath(List<Offset> points, ApexCurve curve) {
    if (points.isEmpty) return Path();
    switch (curve) {
      case ApexCurve.smooth:
        return MonotoneSpline.buildPath(points);
      case ApexCurve.stepline:
        return _steplinePath(points);
      case ApexCurve.straight:
        return _straightPath(points);
    }
  }

  /// Build the closed area path: the line on top, then down to [baselineY] and
  /// back to the start x. Used for area fills (and bar/column gradients later).
  static Path areaPath(
    List<Offset> points,
    ApexCurve curve,
    double baselineY,
  ) {
    if (points.isEmpty) return Path();
    final line = linePath(points, curve);
    final area = Path.from(line);
    area.lineTo(points.last.dx, baselineY);
    area.lineTo(points.first.dx, baselineY);
    area.close();
    return area;
  }

  static Path _straightPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    return path;
  }

  static Path _steplinePath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final midX = (points[i - 1].dx + points[i].dx) / 2;
      path.lineTo(midX, points[i - 1].dy);
      path.lineTo(midX, points[i].dy);
      path.lineTo(points[i].dx, points[i].dy);
    }
    return path;
  }
}
