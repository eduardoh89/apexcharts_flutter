import 'dart:convert';
import 'dart:io';

import 'package:apex_dart/apex_dart.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fixtureOptions(String name) {
  final json = jsonDecode(
    File('tool/fixtures/$name.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return Map<String, dynamic>.from(json['options'] as Map);
}

void main() {
  group('ApexOptions.fromJson — line fixtures', () {
    test('line_simple parses one series + categories', () {
      final o = ApexOptions.fromJson(_fixtureOptions('line_simple'));
      expect(o.type, ApexChartType.line);
      expect(o.series.length, 1);
      expect(o.series.first.points.length, 9);
      expect(o.series.first.points.first.y, 10);
      expect(o.curve, ApexCurve.straight);
      expect(o.strokeWidth, 3);
      expect(o.colors.first, ApexColor.fromHex('#008FFB'));
    });

    test('line_multi parses three series', () {
      final o = ApexOptions.fromJson(_fixtureOptions('line_multi'));
      expect(o.series.length, 3);
      expect(o.categories, hasLength(7));
    });

    test('line_timeseries parses datetime [x,y] pairs', () {
      final o = ApexOptions.fromJson(_fixtureOptions('line_timeseries'));
      expect(o.xAxisType, ApexXAxisType.datetime);
      expect(o.curve, ApexCurve.smooth);
      expect(o.series.first.points.first.x, 1704067200000);
      expect(o.series.first.points.first.y, 30);
    });
  });

  group('ApexOptions.fromJson — bar/pie/donut', () {
    test('bar_grouped parses plotOptions.bar', () {
      final o = ApexOptions.fromJson(_fixtureOptions('bar_grouped'));
      expect(o.type, ApexChartType.bar);
      expect(o.bar.horizontal, isFalse);
      expect(o.bar.columnWidthFraction, closeTo(0.7, 1e-9));
      expect(o.series.length, 2);
    });

    test('pie_basic parses radial series + labels', () {
      final o = ApexOptions.fromJson(_fixtureOptions('pie_basic'));
      expect(o.type, ApexChartType.pie);
      expect(o.pieSeries, [44, 55, 13, 43, 22]);
      expect(o.labels, hasLength(5));
      expect(o.legend.position, ApexLegendPosition.right);
    });

    test('donut_basic parses donut size fraction', () {
      final o = ApexOptions.fromJson(_fixtureOptions('donut_basic'));
      expect(o.type, ApexChartType.donut);
      expect(o.pie.donutSizeFraction, closeTo(0.65, 1e-9));
      expect(o.dataLabelsEnabled, isTrue);
    });
  });

  group('ApexOptions.fromJson — bubble', () {
    test('bubble_basic parses [x,y,z] triplets + numeric axis', () {
      final o = ApexOptions.fromJson(_fixtureOptions('bubble_basic'));
      expect(o.type, ApexChartType.bubble);
      expect(o.type.isCartesian, isTrue);
      expect(o.xAxisType, ApexXAxisType.numeric);
      expect(o.series.length, 2);
      final first = o.series.first.points.first;
      expect(first.x, 10);
      expect(first.y, 30);
      expect(first.z, 25);
      // plotOptions.bubble defaults (Options.js): zScaling true, no clamps.
      expect(o.bubble.zScaling, isTrue);
      expect(o.bubble.minBubbleRadius, isNull);
      expect(o.bubble.maxBubbleRadius, isNull);
      // explicit xaxis.min/max are picked up.
      expect(o.xMin, 0);
      expect(o.xMax, 100);
    });
  });

  group('ApexOptions.fromJson — rangeBar/timeline', () {
    test('rangebar_timeline parses { x, y:[start,end] } range points', () {
      final o = ApexOptions.fromJson(_fixtureOptions('rangebar_timeline'));
      expect(o.type, ApexChartType.rangeBar);
      expect(o.type.isCartesian, isTrue);
      expect(o.bar.horizontal, isTrue);
      // barHeight 60% drives the band thickness fraction.
      expect(o.bar.columnWidthFraction, closeTo(0.6, 1e-9));
      final first = o.series.first.points.first;
      expect(first.isRange, isTrue);
      expect(first.label, 'Design');
      expect(first.y, 1609459200000);
      expect(first.yHigh, 1610668800000);
    });
  });
}
