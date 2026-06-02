import 'package:apex_dart/apex_dart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FormatValue.number', () {
    test('whole numbers print bare', () {
      expect(FormatValue.number(42), '42');
      expect(FormatValue.number(1000), '1000');
    });
    test('decimals trimmed of trailing zeros', () {
      expect(FormatValue.number(3.1400), '3.14');
      expect(FormatValue.number(2.5), '2.5');
    });
  });

  group('FormatValue.formatted', () {
    test('prefix + suffix wrap the value', () {
      const usd = ApexValueFormat(prefix: r'$');
      expect(FormatValue.formatted(1200, usd), r'$1200');
      const pct = ApexValueFormat(suffix: '%');
      expect(FormatValue.formatted(37, pct), '37%');
    });
    test('fixed decimals honoured', () {
      const fmt = ApexValueFormat(prefix: r'$', decimals: 2);
      expect(FormatValue.formatted(9.5, fmt), r'$9.50');
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
          {'name': 'A', 'data': [1, 2, 3]}
        ],
      });
      expect(line.markers.size, 0);

      final withMarkers = ApexOptions.fromJson({
        'chart': {'type': 'line'},
        'markers': {'size': 5},
        'series': [
          {'name': 'A', 'data': [1, 2, 3]}
        ],
      });
      expect(withMarkers.markers.size, 5);

      final scatter = ApexOptions.fromJson({
        'chart': {'type': 'scatter'},
        'series': [
          {'name': 'A', 'data': [[1, 2]]}
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
          {'name': 'A', 'data': [1, 2, 3]}
        ],
      });
      expect(o.yFormat.prefix, r'$');
      expect(o.yFormat.suffix, ' USD');
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
          {'name': 'A', 'data': [1, 2, 3]}
        ],
      });
      expect(o.xTitle.text, 'Month');
      expect(o.yTitle.text, 'Revenue');
    });
  });
}
