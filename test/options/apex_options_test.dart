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

  group('ApexOptions.fromJson — treemap', () {
    test('treemap_basic parses { x, y } tiles + plotOptions.treemap', () {
      final o = ApexOptions.fromJson(_fixtureOptions('treemap_basic'));
      expect(o.type, ApexChartType.treemap);
      expect(o.series.first.points.length, 10);
      expect(o.series.first.points.first.label, 'India');
      expect(o.series.first.points.first.y, 218);
      // treemap defaults (Options.js): enableShades true, shadeIntensity 0.5,
      // distributed false, borderRadius 4.
      expect(o.treemap.enableShades, isTrue);
      expect(o.treemap.shadeIntensity, closeTo(0.5, 1e-9));
      expect(o.treemap.distributed, isFalse);
      expect(o.treemap.borderRadius, 4);
    });
  });

  group('ApexOptions.fromJson — candlestick', () {
    test('candlestick_basic parses { x, y:[o,h,l,c] } OHLC points', () {
      final o = ApexOptions.fromJson(_fixtureOptions('candlestick_basic'));
      expect(o.type, ApexChartType.candlestick);
      expect(o.type.isCartesian, isTrue);
      expect(o.xAxisType, ApexXAxisType.datetime);
      final first = o.series.first.points.first;
      expect(first.isOhlc, isTrue);
      expect(first.ohlc, [51.98, 56.29, 51.59, 53.85]);
      expect(first.x, 1609459200000);
      // candlestick default colors (Options.js).
      expect(o.candlestick.upwardColor, isNull); // not overridden in fixture
    });
  });

  group('ApexOptions.fromJson — heatmap', () {
    test('heatmap_basic parses series rows + plotOptions.heatmap', () {
      final o = ApexOptions.fromJson(_fixtureOptions('heatmap_basic'));
      expect(o.type, ApexChartType.heatmap);
      expect(o.series.length, 4);
      expect(o.series.first.name, 'W1');
      expect(o.series.first.points.length, 5);
      expect(o.series.first.points.first.label, 'Mon');
      // heatmap defaults (Options.js): radius 2, enableShades true,
      // shadeIntensity 0.5.
      expect(o.heatmap.radius, 2);
      expect(o.heatmap.enableShades, isTrue);
      expect(o.heatmap.shadeIntensity, closeTo(0.5, 1e-9));
    });
  });

  group('ApexOptions.fromJson — radar', () {
    test('radar_basic parses series + categories (axis chart)', () {
      final o = ApexOptions.fromJson(_fixtureOptions('radar_basic'));
      expect(o.type, ApexChartType.radar);
      expect(o.type.isRadial, isFalse);
      expect(o.series.length, 2);
      expect(o.series.first.points.length, 6);
      expect(o.categories, hasLength(6));
      expect(o.categories.first, 'Speed');
    });
  });

  group('ApexOptions.fromJson — radialBar', () {
    test('radialbar_basic parses gauge value + plotOptions.radialBar', () {
      final o = ApexOptions.fromJson(_fixtureOptions('radialbar_basic'));
      expect(o.type, ApexChartType.radialBar);
      expect(o.type.isRadial, isTrue);
      expect(o.pieSeries, [70]);
      expect(o.labels, ['Progress']);
      // radialBar defaults (Options.js): startAngle 0, endAngle 360,
      // hollow.size 50%, track.show true, track.margin 5.
      expect(o.radialBar.startAngle, 0);
      expect(o.radialBar.endAngle, 360);
      expect(o.radialBar.hollowSizeFraction, closeTo(0.5, 1e-9));
      expect(o.radialBar.trackShow, isTrue);
      expect(o.radialBar.trackMargin, 5);
    });
  });

  group('ApexOptions.fromJson — logarithmic axis', () {
    test('line_logarithmic parses yaxis.logarithmic + default base', () {
      final o = ApexOptions.fromJson(_fixtureOptions('line_logarithmic'));
      expect(o.logarithmic, isTrue);
      expect(o.logBase, 10);
      expect(o.series.first.points.map((p) => p.y).toList(),
          [1, 10, 100, 1000, 10000, 100000, 1000000]);
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
