import 'package:apexcharts_flutter/apexcharts_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DataLabelsRenderer.horizontalLabelPlacement', () {
    // Reproduces the reported bug: "Porcentaje de ocupación actual - Zona
    // Pública Noruega" — capacity 40 on a 0..40 axis, so the bar ends exactly
    // at the plot's right edge and its "40 cupos" label was clipped to "4"
    // (and occupancy 39 to "39 c").
    const double plotLeft = 40;
    const double plotRight = 600;
    const double labelWidth = 50; // ~"40 cupos" at 11px

    test('a bar reaching the right edge puts its label inside the bar', () {
      final p = DataLabelsRenderer.horizontalLabelPlacement(
        barStart: plotLeft,
        barEnd: plotRight,
        plotLeft: plotLeft,
        plotRight: plotRight,
        textWidth: labelWidth,
      );
      expect(p.inside, isTrue);
      expect(p.anchor, TextAnchor.end);
      expect(p.x - labelWidth, greaterThanOrEqualTo(plotLeft));
      expect(p.x, lessThanOrEqualTo(plotRight));
    });

    test('a bar nearly reaching the edge (39 of 40) also goes inside', () {
      final barEnd = plotLeft + (plotRight - plotLeft) * 39 / 40;
      final p = DataLabelsRenderer.horizontalLabelPlacement(
        barStart: plotLeft,
        barEnd: barEnd,
        plotLeft: plotLeft,
        plotRight: plotRight,
        textWidth: labelWidth,
      );
      expect(p.inside, isTrue);
      expect(p.x, lessThanOrEqualTo(plotRight));
    });

    test('a bar with room to spare keeps the label just past its end', () {
      final barEnd = plotLeft + (plotRight - plotLeft) * 34 / 40;
      final p = DataLabelsRenderer.horizontalLabelPlacement(
        barStart: plotLeft,
        barEnd: barEnd,
        plotLeft: plotLeft,
        plotRight: plotRight,
        textWidth: labelWidth,
      );
      expect(p.inside, isFalse);
      expect(p.anchor, TextAnchor.start);
      expect(p.x, greaterThan(barEnd));
      expect(p.x + labelWidth, lessThanOrEqualTo(plotRight));
    });

    test('a bar too short to hold its label is pinned inside the plot', () {
      // Narrow plot: neither outside nor inside the 20px bar fits the label.
      final p = DataLabelsRenderer.horizontalLabelPlacement(
        barStart: 100,
        barEnd: 120,
        plotLeft: 100,
        plotRight: 120,
        textWidth: labelWidth,
      );
      expect(p.x, 120);
      expect(p.anchor, TextAnchor.end);
    });

    test('negative bars mirror the rule toward the left edge', () {
      final outside = DataLabelsRenderer.horizontalLabelPlacement(
        barStart: 400,
        barEnd: 300,
        plotLeft: plotLeft,
        plotRight: plotRight,
        textWidth: labelWidth,
      );
      expect(outside.inside, isFalse);
      expect(outside.anchor, TextAnchor.end);
      expect(outside.x, lessThan(300));

      final atEdge = DataLabelsRenderer.horizontalLabelPlacement(
        barStart: 400,
        barEnd: plotLeft,
        plotLeft: plotLeft,
        plotRight: plotRight,
        textWidth: labelWidth,
      );
      expect(atEdge.inside, isTrue);
      expect(atEdge.anchor, TextAnchor.start);
      expect(atEdge.x, greaterThanOrEqualTo(plotLeft));
    });
  });
}
