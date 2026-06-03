import 'package:apexcharts_flutter/apexcharts_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Per-chart-type render smoke tests: every supported chart type must pump,
/// lay out, paint and tear down without throwing. These run in CI without any
/// reference PNGs (unlike the golden tests), so they guard against regressions
/// in the render path for all 13 types plus the hover/tooltip path.
void main() {
  Future<void> pumpChart(WidgetTester tester, Map<String, dynamic> json) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 480,
              height: 320,
              child: ApexChart(options: ApexOptions.fromJson(json)),
            ),
          ),
        ),
      ),
    );
    // Let the mount animation settle.
    await tester.pump(const Duration(milliseconds: 1200));
  }

  final cases = <String, Map<String, dynamic>>{
    'line': {
      'chart': {'type': 'line'},
      'series': [
        {
          'name': 'A',
          'data': [10, 41, 35, 51, 49, 62, 69],
        },
      ],
      'xaxis': {
        'categories': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      },
    },
    'area': {
      'chart': {'type': 'area'},
      'stroke': {'curve': 'smooth'},
      'series': [
        {
          'name': 'A',
          'data': [12, 18, 14, 26, 31, 28, 40],
        },
      ],
    },
    'bar-grouped': {
      'chart': {'type': 'bar'},
      'series': [
        {
          'name': '2023',
          'data': [44, 55, 57, 56, 61, 58],
        },
        {
          'name': '2024',
          'data': [76, 85, 101, 98, 87, 105],
        },
      ],
      'xaxis': {
        'categories': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
      },
      'dataLabels': {'enabled': true},
    },
    'bar-stacked': {
      'chart': {'type': 'bar', 'stacked': true},
      'series': [
        {
          'name': 'Q1',
          'data': [20, 30, 25, 40],
        },
        {
          'name': 'Q2',
          'data': [15, 25, 20, 18],
        },
      ],
      'xaxis': {
        'categories': ['Jan', 'Feb', 'Mar', 'Apr'],
      },
    },
    'bar-horizontal': {
      'chart': {'type': 'bar'},
      'plotOptions': {
        'bar': {'horizontal': true},
      },
      'series': [
        {
          'name': 'Score',
          'data': [44, 55, 41, 67, 22],
        },
      ],
      'xaxis': {
        'categories': ['A', 'B', 'C', 'D', 'E'],
      },
    },
    'pie': {
      'chart': {'type': 'pie'},
      'series': [44, 55, 13, 43, 22],
      'labels': ['A', 'B', 'C', 'D', 'E'],
    },
    'donut': {
      'chart': {'type': 'donut'},
      'series': [44, 55, 13, 43],
      'labels': ['A', 'B', 'C', 'D'],
    },
    'scatter': {
      'chart': {'type': 'scatter'},
      'series': [
        {
          'name': 'S',
          'data': [
            [1, 2],
            [3, 5],
            [6, 4],
            [8, 9],
          ],
        },
      ],
    },
    'bubble': {
      'chart': {'type': 'bubble'},
      'series': [
        {
          'name': 'B',
          'data': [
            [10, 20, 30],
            [40, 50, 12],
            [70, 30, 25],
          ],
        },
      ],
      'xaxis': {'min': 0, 'max': 100},
    },
    'rangeBar': {
      'chart': {'type': 'rangeBar'},
      'plotOptions': {
        'bar': {'horizontal': true},
      },
      'series': [
        {
          'name': 'Tasks',
          'data': [
            {
              'x': 'Design',
              'y': [1609459200000, 1610668800000],
            },
            {
              'x': 'Build',
              'y': [1610668800000, 1612483200000],
            },
          ],
        },
      ],
      'xaxis': {'type': 'datetime'},
    },
    'candlestick': {
      'chart': {'type': 'candlestick'},
      'series': [
        {
          'name': 'OHLC',
          'data': [
            {
              'x': 1609459200000,
              'y': [51.98, 56.29, 51.59, 53.85],
            },
            {
              'x': 1609545600000,
              'y': [53.66, 54.99, 51.35, 52.95],
            },
          ],
        },
      ],
      'xaxis': {'type': 'datetime'},
    },
    'radar': {
      'chart': {'type': 'radar'},
      'series': [
        {
          'name': 'A',
          'data': [80, 50, 30, 40, 100, 20],
        },
      ],
      'xaxis': {
        'categories': ['M', 'T', 'W', 'Th', 'F', 'S'],
      },
    },
    'radialBar': {
      'chart': {'type': 'radialBar'},
      'series': [70],
      'labels': ['Progress'],
    },
    'heatmap': {
      'chart': {'type': 'heatmap'},
      'series': [
        {
          'name': 'W1',
          'data': [
            {'x': 'Mon', 'y': 10},
            {'x': 'Tue', 'y': 40},
            {'x': 'Wed', 'y': 90},
          ],
        },
        {
          'name': 'W2',
          'data': [
            {'x': 'Mon', 'y': 50},
            {'x': 'Tue', 'y': 20},
            {'x': 'Wed', 'y': 60},
          ],
        },
      ],
      'xaxis': {
        'type': 'category',
        'categories': ['Mon', 'Tue', 'Wed'],
      },
    },
    'treemap': {
      'chart': {'type': 'treemap'},
      'series': [
        {
          'name': 'Desktops',
          'data': [
            {'x': 'India', 'y': 218},
            {'x': 'USA', 'y': 149},
            {'x': 'China', 'y': 184},
            {'x': 'Japan', 'y': 55},
          ],
        },
      ],
    },
  };

  group('renders without throwing', () {
    for (final entry in cases.entries) {
      testWidgets('${entry.key} chart', (tester) async {
        await pumpChart(tester, entry.value);
        expect(find.byType(ApexChart), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('hover does not throw', () {
    // Exercise the tooltip/hit-test path on a representative chart of each
    // hit-testing family: cartesian, pie, tile (heatmap), radar.
    final hoverCases = {
      'line': cases['line']!,
      'pie': cases['pie']!,
      'heatmap': cases['heatmap']!,
      'radar': cases['radar']!,
    };
    for (final entry in hoverCases.entries) {
      testWidgets('${entry.key} hover', (tester) async {
        await pumpChart(tester, entry.value);
        final gesture =
            await tester.createGesture(kind: PointerDeviceKind.mouse);
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await gesture.moveTo(tester.getCenter(find.byType(ApexChart)));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
