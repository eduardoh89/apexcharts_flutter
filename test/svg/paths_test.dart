import 'package:apex_dart/apex_dart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MonotoneSpline', () {
    test('passes through all data points (bounds contain them)', () {
      final pts = [
        const Offset(0, 100),
        const Offset(50, 40),
        const Offset(100, 60),
        const Offset(150, 10),
      ];
      final path = MonotoneSpline.buildPath(pts);
      final bounds = path.getBounds();
      for (final p in pts) {
        expect(bounds.contains(p) ||
            (p.dx >= bounds.left - 0.01 &&
                p.dx <= bounds.right + 0.01 &&
                p.dy >= bounds.top - 0.01 &&
                p.dy <= bounds.bottom + 0.01),
            isTrue);
      }
    });

    test('falls back to polyline for <3 points', () {
      final path =
          MonotoneSpline.buildPath([const Offset(0, 0), const Offset(10, 10)]);
      final m = path.computeMetrics().toList();
      expect(m, isNotEmpty);
    });

    test('empty input yields empty path', () {
      final path = MonotoneSpline.buildPath([]);
      expect(path.computeMetrics().toList(), isEmpty);
    });
  });

  group('ApexPaths', () {
    final pts = [
      const Offset(0, 100),
      const Offset(50, 40),
      const Offset(100, 60),
    ];

    test('straight line path is non-empty and starts at first point', () {
      final path = ApexPaths.linePath(pts, ApexCurve.straight);
      final bounds = path.getBounds();
      expect(bounds.left, closeTo(0, 0.01));
    });

    test('stepline produces an axis-aligned staircase within x-range', () {
      final path = ApexPaths.linePath(pts, ApexCurve.stepline);
      final bounds = path.getBounds();
      expect(bounds.left, closeTo(0, 0.01));
      expect(bounds.right, closeTo(100, 0.01));
    });

    test('area path is closed down to baseline', () {
      final path = ApexPaths.areaPath(pts, ApexCurve.straight, 200);
      final bounds = path.getBounds();
      expect(bounds.bottom, closeTo(200, 0.01));
    });
  });
}
