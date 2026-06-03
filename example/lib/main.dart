import 'package:apexcharts_flutter/apexcharts_flutter.dart';
import 'package:flutter/material.dart';

import 'area_datetime_demo.dart';

void main() => runApp(const GalleryApp());

/// A gallery that renders every apexcharts_flutter chart type so the port can
/// be eyeballed on any Flutter platform (Android, iOS, web, Windows, macOS,
/// Linux).
class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'apexcharts_flutter gallery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
      ),
      home: const GalleryPage(),
    );
  }
}

class ChartSpec {
  const ChartSpec(this.title, this.json);
  final String title;
  final Map<String, dynamic> json;
}

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  List<ChartSpec> get _specs => [
        ChartSpec('Line — markers + axis titles + \$ format', {
          'chart': {'type': 'line'},
          'stroke': {'curve': 'straight', 'width': 3},
          'colors': ['#008FFB'],
          'markers': {'size': 5},
          'series': [
            {
              'name': 'Sales',
              'data': [10, 41, 35, 51, 49, 62, 69, 91, 148]
            }
          ],
          'xaxis': {
            'categories': [1, 2, 3, 4, 5, 6, 7, 8, 9],
            'title': {'text': 'Week'},
          },
          'yaxis': {
            'title': {'text': 'Revenue'},
          },
          'tooltip': {
            'y': {'prefix': r'$', 'suffix': 'k'}
          },
          'dataLabels': {'enabled': false},
        }),
        ChartSpec('Line — multi-series', {
          'chart': {'type': 'line'},
          'stroke': {'curve': 'straight', 'width': 3},
          'colors': ['#008FFB', '#00E396', '#FEB019'],
          'series': [
            {
              'name': 'Team A',
              'data': [31, 40, 28, 51, 42, 109, 100]
            },
            {
              'name': 'Team B',
              'data': [11, 32, 45, 32, 34, 52, 41]
            },
            {
              'name': 'Team C',
              'data': [15, 11, 32, 18, 9, 24, 11]
            },
          ],
          'xaxis': {
            'categories': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
          },
        }),
        ChartSpec('Line — zoomable timeseries (drag / wheel to zoom)', {
          'chart': {
            'type': 'line',
            'zoom': {'enabled': true}
          },
          'stroke': {'curve': 'smooth', 'width': 3},
          'colors': ['#775DD0'],
          'series': [
            {
              'name': 'Visitors',
              'data': [
                for (int d = 0; d < 40; d++)
                  [
                    1704067200000 + d * 86400000,
                    (30 +
                            35 *
                                (0.5 +
                                    0.5 * (d % 7 == 0 ? 1.0 : (d % 5) / 5.0)) +
                            (d * 1.4))
                        .round()
                  ]
              ],
            }
          ],
          'xaxis': {'type': 'datetime'},
        }),
        ChartSpec('Area — with data labels', {
          'chart': {'type': 'area'},
          'stroke': {'curve': 'smooth', 'width': 2},
          'colors': ['#00E396'],
          'series': [
            {
              'name': 'Revenue',
              'data': [12, 18, 14, 26, 31, 28, 40, 52]
            }
          ],
          'xaxis': {
            'categories': [
              'Jan',
              'Feb',
              'Mar',
              'Apr',
              'May',
              'Jun',
              'Jul',
              'Aug'
            ]
          },
          'dataLabels': {'enabled': true},
        }),
        ChartSpec('Bar — grouped (data labels)', {
          'chart': {'type': 'bar'},
          'plotOptions': {
            'bar': {'horizontal': false, 'columnWidth': '70%'}
          },
          'colors': ['#008FFB', '#00E396'],
          'series': [
            {
              'name': '2023',
              'data': [44, 55, 57, 56, 61, 58]
            },
            {
              'name': '2024',
              'data': [76, 85, 101, 98, 87, 105]
            },
          ],
          'xaxis': {
            'categories': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun']
          },
          'dataLabels': {'enabled': true},
        }),
        ChartSpec('Bar — stacked', {
          'chart': {'type': 'bar', 'stacked': true},
          'plotOptions': {
            'bar': {'horizontal': false, 'columnWidth': '60%'}
          },
          'colors': ['#008FFB', '#00E396', '#FEB019'],
          'series': [
            {
              'name': 'Q1',
              'data': [20, 30, 25, 40, 32, 28]
            },
            {
              'name': 'Q2',
              'data': [15, 25, 20, 18, 22, 30]
            },
            {
              'name': 'Q3',
              'data': [10, 12, 18, 22, 15, 20]
            },
          ],
          'xaxis': {
            'categories': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun']
          },
        }),
        ChartSpec('Bar — horizontal', {
          'chart': {'type': 'bar'},
          'plotOptions': {
            'bar': {'horizontal': true, 'columnWidth': '70%'}
          },
          'colors': ['#FF4560'],
          'series': [
            {
              'name': 'Score',
              'data': [44, 55, 41, 67, 22, 43]
            }
          ],
          'xaxis': {
            'categories': ['A', 'B', 'C', 'D', 'E', 'F']
          },
        }),
        ChartSpec('Scatter', {
          'chart': {'type': 'scatter'},
          'colors': ['#008FFB', '#FF4560'],
          'series': [
            {
              'name': 'Sample A',
              'data': [
                [10, 21],
                [22, 35],
                [33, 28],
                [45, 50],
                [58, 41],
                [70, 63]
              ],
            },
            {
              'name': 'Sample B',
              'data': [
                [12, 11],
                [25, 18],
                [38, 25],
                [50, 20],
                [62, 33],
                [75, 28]
              ],
            },
          ],
          'xaxis': {'type': 'numeric'},
        }),
        ChartSpec('Bubble', {
          'chart': {'type': 'bubble'},
          'colors': ['#008FFB', '#00E396', '#FEB019'],
          'dataLabels': {'enabled': false},
          'series': [
            {
              'name': 'Bubble A',
              'data': [
                [10, 30, 25],
                [25, 55, 40],
                [40, 20, 60],
                [55, 70, 30],
                [70, 45, 50],
                [85, 60, 20]
              ],
            },
            {
              'name': 'Bubble B',
              'data': [
                [15, 50, 35],
                [30, 25, 55],
                [48, 65, 25],
                [62, 35, 45],
                [78, 55, 60],
                [92, 40, 30]
              ],
            },
          ],
          'xaxis': {'type': 'numeric', 'min': 0, 'max': 100, 'tickAmount': 10},
          'yaxis': {'max': 80},
          'legend': {'show': false},
        }),
        ChartSpec('Timeline (rangeBar)', {
          'chart': {'type': 'rangeBar'},
          'plotOptions': {
            'bar': {'horizontal': true, 'barHeight': '60%'}
          },
          'dataLabels': {'enabled': false},
          'colors': ['#008FFB'],
          'series': [
            {
              'name': 'Tasks',
              'data': [
                {
                  'x': 'Design',
                  'y': [1609459200000, 1610668800000]
                },
                {
                  'x': 'Build',
                  'y': [1610668800000, 1612483200000]
                },
                {
                  'x': 'Test',
                  'y': [1612483200000, 1613692800000]
                },
                {
                  'x': 'Deploy',
                  'y': [1613692800000, 1614297600000]
                },
              ],
            }
          ],
          'xaxis': {'type': 'datetime'},
          'legend': {'show': false},
        }),
        ChartSpec('RadialBar (gauge)', {
          'chart': {'type': 'radialBar'},
          'colors': ['#008FFB'],
          'series': [70],
          'labels': ['Progress'],
          'plotOptions': {
            'radialBar': {
              'hollow': {'size': '50%'},
              'track': {'show': true},
            }
          },
          'legend': {'show': false},
        }),
        ChartSpec('Radar', {
          'chart': {'type': 'radar'},
          'colors': ['#008FFB', '#FF4560'],
          'dataLabels': {'enabled': false},
          'series': [
            {
              'name': 'Series A',
              'data': [80, 50, 30, 40, 100, 20]
            },
            {
              'name': 'Series B',
              'data': [20, 30, 40, 80, 20, 80]
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
            ]
          },
          'legend': {'show': false},
        }),
        ChartSpec('HeatMap', {
          'chart': {'type': 'heatmap'},
          'dataLabels': {'enabled': false},
          'colors': ['#008FFB'],
          'series': [
            {
              'name': 'W1',
              'data': [
                {'x': 'Mon', 'y': 10},
                {'x': 'Tue', 'y': 40},
                {'x': 'Wed', 'y': 30},
                {'x': 'Thu', 'y': 70},
                {'x': 'Fri', 'y': 90}
              ]
            },
            {
              'name': 'W2',
              'data': [
                {'x': 'Mon', 'y': 50},
                {'x': 'Tue', 'y': 20},
                {'x': 'Wed', 'y': 60},
                {'x': 'Thu', 'y': 30},
                {'x': 'Fri', 'y': 10}
              ]
            },
            {
              'name': 'W3',
              'data': [
                {'x': 'Mon', 'y': 80},
                {'x': 'Tue', 'y': 60},
                {'x': 'Wed', 'y': 20},
                {'x': 'Thu', 'y': 40},
                {'x': 'Fri', 'y': 100}
              ]
            },
            {
              'name': 'W4',
              'data': [
                {'x': 'Mon', 'y': 30},
                {'x': 'Tue', 'y': 90},
                {'x': 'Wed', 'y': 50},
                {'x': 'Thu', 'y': 70},
                {'x': 'Fri', 'y': 40}
              ]
            },
          ],
          'xaxis': {
            'type': 'category',
            'categories': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']
          },
          'legend': {'show': false},
        }),
        ChartSpec('Candlestick', {
          'chart': {'type': 'candlestick'},
          'series': [
            {
              'name': 'OHLC',
              'data': [
                {
                  'x': 1609459200000,
                  'y': [51.98, 56.29, 51.59, 53.85]
                },
                {
                  'x': 1609545600000,
                  'y': [53.66, 54.99, 51.35, 52.95]
                },
                {
                  'x': 1609632000000,
                  'y': [52.76, 57.35, 52.15, 57.03]
                },
                {
                  'x': 1609718400000,
                  'y': [57.00, 58.20, 54.80, 55.10]
                },
                {
                  'x': 1609804800000,
                  'y': [55.20, 59.40, 55.00, 58.90]
                },
                {
                  'x': 1609891200000,
                  'y': [58.80, 60.10, 56.70, 57.20]
                },
                {
                  'x': 1609977600000,
                  'y': [57.10, 61.30, 56.90, 60.80]
                },
                {
                  'x': 1610064000000,
                  'y': [60.70, 62.50, 59.20, 59.60]
                },
              ],
            }
          ],
          'xaxis': {'type': 'datetime'},
        }),
        ChartSpec('Treemap', {
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
                {'x': 'France', 'y': 70},
                {'x': 'Canada', 'y': 30},
                {'x': 'Italy', 'y': 44},
                {'x': 'Spain', 'y': 68},
              ],
            }
          ],
        }),
        ChartSpec('Pie', {
          'chart': {'type': 'pie'},
          'colors': ['#008FFB', '#00E396', '#FEB019', '#FF4560', '#775DD0'],
          'series': [44, 55, 13, 43, 22],
          'labels': ['Team A', 'Team B', 'Team C', 'Team D', 'Team E'],
          'legend': {'position': 'right'},
          'dataLabels': {'enabled': true},
        }),
        ChartSpec('Donut', {
          'chart': {'type': 'donut'},
          'colors': ['#008FFB', '#00E396', '#FEB019', '#FF4560'],
          'series': [44, 55, 41, 17],
          'labels': ['Comedy', 'Action', 'SciFi', 'Drama'],
          'plotOptions': {
            'pie': {
              'donut': {'size': '65%'}
            }
          },
          'legend': {'position': 'right'},
          'dataLabels': {'enabled': true},
        }),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'apex_dart — ApexCharts v4.7.0 native port  ·  hover any chart for tooltips',
        ),
        backgroundColor: const Color(0xFF008FFB),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AreaDatetimeDemo(),
                ),
              ),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Area-Datetime demo →'),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxis = constraints.maxWidth > 1100 ? 2 : 1;
          return GridView.count(
            crossAxisCount: crossAxis,
            childAspectRatio: 1.7,
            padding: const EdgeInsets.all(16),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              for (final spec in _specs)
                Card(
                  elevation: 1,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spec.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF373D3F),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: ApexChart(
                            options: ApexOptions.fromJson(spec.json)
                                .copyWith(fontFamily: 'Inter'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
