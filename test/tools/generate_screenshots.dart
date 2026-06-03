@Tags(['screenshots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:apexcharts_flutter/apexcharts_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Not a real test: a one-shot generator that rasterizes a set of charts —
/// rendered by apexcharts_flutter itself — into doc/screenshots/*.png for the
/// README and the pub.dev screenshots carousel. Run with:
///   flutter test --tags screenshots test/tools/generate_screenshots.dart
void main() {
  const outDir = 'doc/screenshots';
  Directory(outDir).createSync(recursive: true);

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Map<String, dynamic> json, {
    double width = 640,
    double height = 400,
  }) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: Container(
              width: width,
              height: height,
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: ApexChart(
                options:
                    ApexOptions.fromJson(json).copyWith(fontFamily: 'Inter'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      // 2x for crisp images on high-DPI screens / README.
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$outDir/$name.png')
          .writeAsBytesSync(data!.buffer.asUint8List(), flush: true);
    });
  }

  testWidgets('generate screenshots', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));

    await shoot(tester, 'line', {
      // Toolbar icons use MaterialIcons, which the test harness doesn't load
      // (they'd render as empty boxes), so hide the toolbar for the still.
      'chart': {
        'type': 'line',
        'zoom': {'enabled': false},
        'toolbar': {'show': false},
      },
      'stroke': {'curve': 'smooth', 'width': 3},
      'colors': ['#008FFB', '#00E396', '#FEB019'],
      'series': [
        {
          'name': 'Team A',
          'data': [31, 40, 28, 51, 42, 109, 100],
        },
        {
          'name': 'Team B',
          'data': [11, 32, 45, 32, 34, 52, 41],
        },
        {
          'name': 'Team C',
          'data': [15, 11, 32, 18, 9, 24, 11],
        },
      ],
      'xaxis': {
        'categories': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      },
    });

    await shoot(tester, 'area', {
      'chart': {
        'type': 'area',
        'zoom': {'enabled': false},
        'toolbar': {'show': false},
      },
      'stroke': {'curve': 'smooth', 'width': 2},
      'colors': ['#008FFB'],
      'series': [
        {
          'name': 'Revenue',
          'data': [12, 18, 14, 26, 31, 28, 40, 52, 47, 60],
        },
      ],
      'fill': {
        'type': 'gradient',
        'gradient': {
          'shadeIntensity': 1,
          'opacityFrom': 0.7,
          'opacityTo': 0.2,
          'stops': [0, 100],
        },
      },
      'dataLabels': {'enabled': false},
    });

    await shoot(tester, 'bar', {
      'chart': {'type': 'bar'},
      'plotOptions': {
        'bar': {'horizontal': false, 'columnWidth': '60%'},
      },
      'colors': ['#008FFB', '#00E396'],
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
    });

    await shoot(tester, 'pie', {
      'chart': {'type': 'pie'},
      'colors': ['#008FFB', '#00E396', '#FEB019', '#FF4560', '#775DD0'],
      'series': [44, 55, 13, 43, 22],
      'labels': ['Team A', 'Team B', 'Team C', 'Team D', 'Team E'],
      'legend': {'position': 'right'},
      'dataLabels': {'enabled': true},
    });

    await shoot(tester, 'radar', {
      'chart': {'type': 'radar'},
      'colors': ['#008FFB', '#FF4560'],
      'series': [
        {
          'name': 'Series 1',
          'data': [80, 50, 30, 40, 100, 20],
        },
        {
          'name': 'Series 2',
          'data': [20, 30, 40, 80, 20, 80],
        },
      ],
      'xaxis': {
        'categories': [
          'Speed',
          'Power',
          'Range',
          'Armor',
          'Agility',
          'Stealth'
        ],
      },
    });

    await shoot(tester, 'candlestick', {
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
            {
              'x': 1609632000000,
              'y': [52.76, 57.35, 52.15, 57.03],
            },
            {
              'x': 1609718400000,
              'y': [57.00, 58.20, 54.80, 55.10],
            },
            {
              'x': 1609804800000,
              'y': [55.20, 59.40, 55.00, 58.90],
            },
            {
              'x': 1609891200000,
              'y': [58.80, 60.10, 56.70, 57.20],
            },
            {
              'x': 1609977600000,
              'y': [57.10, 61.30, 56.90, 60.80],
            },
            {
              'x': 1610064000000,
              'y': [60.70, 62.50, 59.20, 59.60],
            },
          ],
        },
      ],
      'xaxis': {'type': 'datetime'},
    });

    await shoot(tester, 'heatmap', {
      'chart': {'type': 'heatmap'},
      'colors': ['#008FFB'],
      'series': [
        for (int w = 1; w <= 4; w++)
          {
            'name': 'W$w',
            'data': [
              for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'])
                {'x': d, 'y': (20 + (w * 13 + d.hashCode % 60)).abs() % 100},
            ],
          },
      ],
      'xaxis': {
        'type': 'category',
        'categories': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
      },
      'legend': {'show': false},
    });

    await shoot(tester, 'treemap', {
      'chart': {'type': 'treemap'},
      'legend': {'show': false},
      'colors': ['#008FFB'],
      'dataLabels': {'enabled': true},
      'series': [
        {
          'name': 'Desktops',
          'data': [
            {'x': 'India', 'y': 218},
            {'x': 'USA', 'y': 149},
            {'x': 'China', 'y': 184},
            {'x': 'Japan', 'y': 55},
            {'x': 'Germany', 'y': 84},
            {'x': 'Brazil', 'y': 31},
            {'x': 'Canada', 'y': 30},
            {'x': 'Italy', 'y': 44},
            {'x': 'Spain', 'y': 68},
            {'x': 'France', 'y': 72},
          ],
        },
      ],
    });

    // ignore: avoid_print
    print('Screenshots written to $outDir');
  });
}
