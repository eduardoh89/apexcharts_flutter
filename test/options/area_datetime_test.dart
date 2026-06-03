import 'package:apexcharts_flutter/apexcharts_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FormatValue.date', () {
    // 2012-11-14 (epoch ms, local-time independent fields below use UTC-safe day).
    const ms = 1352847600000;

    test('dd MMM yyyy format', () {
      final s = FormatValue.date(ms, 'dd MMM yyyy');
      expect(s, matches(r'^\d{2} [A-Z][a-z]{2} \d{4}$'));
      expect(s.contains('Nov'), isTrue);
      expect(s.contains('2012'), isTrue);
    });

    test('null format falls back to "d MMM"', () {
      final s = FormatValue.date(ms, null);
      expect(s.contains('Nov'), isTrue);
    });
  });

  group('area-datetime options parsing', () {
    final o = ApexOptions.fromJson({
      'chart': {
        'type': 'area',
        'zoom': {'autoScaleYaxis': true}
      },
      'colors': ['#008FFB'],
      'series': [
        {
          'name': 'ABC',
          'data': [
            [1327359600000, 30.95],
            [1327446000000, 31.34]
          ]
        }
      ],
      'xaxis': {'type': 'datetime', 'min': 1330578000000, 'tickAmount': 6},
      'tooltip': {
        'x': {'format': 'dd MMM yyyy'}
      },
      'fill': {
        'type': 'gradient',
        'gradient': {
          'opacityFrom': 0.7,
          'opacityTo': 0.9,
          'stops': [0, 100]
        }
      },
      'annotations': {
        'yaxis': [
          {
            'y': 30,
            'borderColor': '#999',
            'label': {
              'text': 'Support',
              'style': {'color': '#fff', 'background': '#00E396'}
            }
          }
        ],
        'xaxis': [
          {
            'x': 1352847600000,
            'borderColor': '#999',
            'label': {
              'text': 'Rally',
              'style': {'color': '#fff', 'background': '#775DD0'}
            }
          }
        ],
      },
    });

    test('xaxis.min / tickAmount parsed', () {
      expect(o.xMin, 1330578000000);
      expect(o.tickAmount, 6);
    });

    test('zoom.autoScaleYaxis parsed', () {
      expect(o.zoom.autoScaleYaxis, isTrue);
    });

    test('gradient fill parsed', () {
      expect(o.gradient.enabled, isTrue);
      expect(o.gradient.opacityFrom, 0.7);
      expect(o.gradient.opacityTo, 0.9);
      expect(o.gradient.stops, [0, 100]);
    });

    test('tooltip x format parsed', () {
      expect(o.tooltipXFormat, 'dd MMM yyyy');
    });

    test('annotations parsed (1 yaxis + 1 xaxis)', () {
      expect(o.annotations.length, 2);
      final yAnno = o.annotations.firstWhere((a) => !a.isXAxis);
      expect(yAnno.value, 30);
      expect(yAnno.labelText, 'Support');
      final xAnno = o.annotations.firstWhere((a) => a.isXAxis);
      expect(xAnno.value, 1352847600000);
      expect(xAnno.labelText, 'Rally');
    });
  });
}
