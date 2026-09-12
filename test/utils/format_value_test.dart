import 'package:apexcharts_flutter/apexcharts_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FormatValue.number', () {
    test('whole numbers under 1000 print bare', () {
      expect(FormatValue.number(42), '42');
    });
    test('decimals trimmed of trailing zeros, comma as decimal separator', () {
      expect(FormatValue.number(2.5), '2,5');
      expect(FormatValue.number(2.0), '2');
    });

    // Reproduces the reported bug: a chart tooltip showed "tarifa promedio:
    // 4.988,822" — 3 decimals read as noisy false precision on an average.
    // The default cap dropped from 3 to 1 decimal.
    test('rounds to at most 1 decimal by default, not 3', () {
      expect(FormatValue.number(4988.822), '4.988,8');
      expect(FormatValue.number(3.1400), '3,1');
    });

    test('an explicit maxDecimals still overrides the 1-decimal default', () {
      expect(FormatValue.number(3.14159, maxDecimals: 3), '3,142');
    });

    // Reproduces the reported bug: axis labels and tooltips on
    // "Comparativa Semanal DBNet" showed raw values like "6914150" and
    // "8000000" — real ApexCharts doesn't group thousands by default, but
    // that reads as a wall of digits on a real dashboard. REVIA groups them
    // Chilean/Spanish-style: `.` every 3 digits, `,` for decimals.
    group('thousands grouping (REVIA deviation from upstream)', () {
      test('groups a 6-digit whole number', () {
        expect(FormatValue.number(740100), '740.100');
      });
      test('groups a 7-digit whole number at two separators', () {
        expect(FormatValue.number(6914150), '6.914.150');
        expect(FormatValue.number(8000000), '8.000.000');
      });
      test('groups the integer part while keeping a comma decimal', () {
        expect(FormatValue.number(1234.5), '1.234,5');
      });
      test('a value under 1000 has no separator to insert', () {
        expect(FormatValue.number(999), '999');
      });
      test('negative values keep the sign outside the grouping', () {
        expect(FormatValue.number(-740100), '-740.100');
      });
      test('the documented "1,2" example formats exactly as written', () {
        expect(FormatValue.number(1.2), '1,2');
      });
    });
  });

  group('FormatValue.formatted', () {
    test('prefix + suffix wrap the grouped value', () {
      const usd = ApexValueFormat(prefix: r'$');
      expect(FormatValue.formatted(1200, usd), r'$1.200');
      const pct = ApexValueFormat(suffix: '%');
      expect(FormatValue.formatted(37, pct), '37%');
    });
    test('fixed decimals are grouped and comma-separated too', () {
      const fmt = ApexValueFormat(prefix: r'$', decimals: 2);
      expect(FormatValue.formatted(9.5, fmt), r'$9,50');
      expect(FormatValue.formatted(1200.5, fmt), r'$1.200,50');
    });
    test('identity format equals bare number', () {
      const id = ApexValueFormat();
      expect(id.isIdentity, isTrue);
      expect(FormatValue.formatted(50, id), '50');
    });
  });

  group('ApexOptions parsing of new features', () {
    test('markers.size parsed; line default is 0, scatter default is 6', () {
      final line = ApexOptions.fromJson({
        'chart': {'type': 'line'},
        'series': [
          {
            'name': 'A',
            'data': [1, 2, 3]
          }
        ],
      });
      expect(line.markers.size, 0);

      final withMarkers = ApexOptions.fromJson({
        'chart': {'type': 'line'},
        'markers': {'size': 5},
        'series': [
          {
            'name': 'A',
            'data': [1, 2, 3]
          }
        ],
      });
      expect(withMarkers.markers.size, 5);

      final scatter = ApexOptions.fromJson({
        'chart': {'type': 'scatter'},
        'series': [
          {
            'name': 'A',
            'data': [
              [1, 2]
            ]
          }
        ],
      });
      expect(scatter.markers.size, 6);
    });

    test('tooltip.y prefix/suffix parsed into yFormat', () {
      final o = ApexOptions.fromJson({
        'chart': {'type': 'line'},
        'tooltip': {
          'y': {'prefix': r'$', 'suffix': ' USD'}
        },
        'series': [
          {
            'name': 'A',
            'data': [1, 2, 3]
          }
        ],
      });
      expect(o.yFormat.prefix, r'$');
      expect(o.yFormat.suffix, ' USD');
    });

    // Reproduces the reported bug: "Tarifa Promedio Diaria Histórica -
    // Sucursal 14" showed a tooltip value of "4.988,822" (3 decimals) even
    // though the chart_config explicitly asked for yaxis.labels.decimals:0.
    // `tooltip.y` was present (it carried an unrelated `title.formatter`
    // key) so the old `tooltip?['y'] ?? yaxisMap?['labels']` never even
    // looked at yaxis.labels, silently dropping the decimals:0 request.
    test('yaxis.labels.decimals is honored when tooltip.y sets nothing formatting-related', () {
      final o = ApexOptions.fromJson({
        'chart': {'type': 'bar'},
        'tooltip': {
          'y': {'title': {'formatter': 'Tarifa'}, 'formatter': null},
        },
        'yaxis': {
          'labels': {'decimals': 0},
        },
        'series': [
          {'name': 'A', 'data': [1, 2, 3]}
        ],
      });
      expect(o.yFormat.decimals, 0);
    });

    test('a field tooltip.y DOES set still wins over the same field on yaxis.labels', () {
      final o = ApexOptions.fromJson({
        'chart': {'type': 'bar'},
        'tooltip': {
          'y': {'decimals': 2},
        },
        'yaxis': {
          'labels': {'decimals': 0},
        },
        'series': [
          {'name': 'A', 'data': [1, 2, 3]}
        ],
      });
      expect(o.yFormat.decimals, 2);
    });

    // Reproduces the reported bug: "Eventos del Diario Europa por hora"
    // showed a bare "0, 3.83, 7.67..." x-axis with no unit, and a tooltip
    // with no " eventos" suffix — the AI-authored chart_config specified
    // both via a `formatter` JS function string (real ApexCharts evaluates
    // it; this engine can't), which was previously silently ignored
    // entirely — not even attempted, since ApexValueFormat.parse only read
    // literal `{prefix, suffix}` keys.
    group('JS `formatter` function string (REVIA — never eval, pattern-match only)', () {
      test('a `val + \'X\'` suffix pattern is extracted from tooltip.y', () {
        final o = ApexOptions.fromJson({
          'chart': {'type': 'bar'},
          'tooltip': {
            'y': {'formatter': "function(val) { return val + ' eventos'; }"}
          },
          'series': [
            {'name': 'A', 'data': [1, 2, 3]}
          ],
        });
        expect(o.yFormat.suffix, ' eventos');
        expect(o.yFormat.prefix, '');
      });

      test('a `val + \'X\'` suffix pattern is extracted from xaxis.labels for a numeric axis', () {
        final o = ApexOptions.fromJson({
          'chart': {'type': 'bar'},
          'xaxis': {
            'type': 'numeric',
            'labels': {'formatter': "function(val) { return val + 'h'; }"}
          },
          'series': [
            {'name': 'A', 'data': [1, 2, 3]}
          ],
        });
        expect(o.xLabelFormat.suffix, 'h');
      });

      test('tooltip.x takes precedence over xaxis.labels, matching yFormat precedence', () {
        final o = ApexOptions.fromJson({
          'chart': {'type': 'bar'},
          'tooltip': {
            'x': {'formatter': "function(val) { return val + 'h'; }"}
          },
          'xaxis': {
            'type': 'numeric',
            'labels': {'formatter': "function(val) { return val + ' units'; }"}
          },
          'series': [
            {'name': 'A', 'data': [1, 2, 3]}
          ],
        });
        expect(o.xLabelFormat.suffix, 'h');
      });

      test('a `\'X\' + val` prefix pattern is extracted', () {
        final o = ApexOptions.fromJson({
          'chart': {'type': 'bar'},
          'tooltip': {
            'y': {'formatter': "function(val) { return '\$' + val; }"}
          },
          'series': [
            {'name': 'A', 'data': [1, 2, 3]}
          ],
        });
        expect(o.yFormat.prefix, r'$');
        expect(o.yFormat.suffix, '');
      });

      test('a formatter beyond the recognized shape is left unparsed, not guessed at', () {
        final o = ApexOptions.fromJson({
          'chart': {'type': 'bar'},
          'tooltip': {
            'y': {
              'formatter': 'function(val) { return val > 100 ? "high" : "low"; }'
            }
          },
          'series': [
            {'name': 'A', 'data': [1, 2, 3]}
          ],
        });
        expect(o.yFormat.isIdentity, isTrue);
      });

      test('explicit prefix/suffix keys win over a formatter string', () {
        final o = ApexOptions.fromJson({
          'chart': {'type': 'bar'},
          'tooltip': {
            'y': {
              'suffix': ' explicit',
              'formatter': "function(val) { return val + ' ignored'; }",
            }
          },
          'series': [
            {'name': 'A', 'data': [1, 2, 3]}
          ],
        });
        expect(o.yFormat.suffix, ' explicit');
      });
    });

    test('axis titles parsed', () {
      final o = ApexOptions.fromJson({
        'chart': {'type': 'line'},
        'xaxis': {
          'title': {'text': 'Month'}
        },
        'yaxis': {
          'title': {'text': 'Revenue'}
        },
        'series': [
          {
            'name': 'A',
            'data': [1, 2, 3]
          }
        ],
      });
      expect(o.xTitle.text, 'Month');
      expect(o.yTitle.text, 'Revenue');
    });
  });
}
