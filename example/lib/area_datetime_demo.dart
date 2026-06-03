import 'package:apexcharts_flutter/apexcharts_flutter.dart';
import 'package:flutter/material.dart';

import 'area_datetime_data.dart';

/// Faithful replica of the ApexCharts "Area Chart - Datetime X-axis" demo:
/// https://apexcharts.com/javascript-chart-demos/area-charts/area-datetime/
///
/// Includes the gradient area fill, the Support (yaxis) and Rally (xaxis)
/// annotations, the initial `xaxis.min = 01 Mar 2012` window, the
/// `dd MMM yyyy` tooltip date format, and the 1M / 6M / 1Y / YTD / ALL range
/// buttons driven via [ApexChartController.zoomX].
class AreaDatetimeDemo extends StatefulWidget {
  const AreaDatetimeDemo({super.key});

  @override
  State<AreaDatetimeDemo> createState() => _AreaDatetimeDemoState();
}

class _AreaDatetimeDemoState extends State<AreaDatetimeDemo> {
  final _controller = ApexChartController();
  String _active = '1M';

  static int _ms(String date) => DateTime.parse(date).millisecondsSinceEpoch;

  late final ApexOptions _options = ApexOptions.fromJson({
    'chart': {
      'type': 'area',
      'zoom': {'autoScaleYaxis': true},
    },
    'colors': ['#008FFB'],
    'dataLabels': {'enabled': false},
    'markers': {'size': 0},
    'series': [
      {'name': 'STOCK ABC', 'data': areaDatetimeSeries}
    ],
    'xaxis': {
      'type': 'datetime',
      'min': _ms('2012-03-01'),
      'tickAmount': 6,
    },
    'tooltip': {
      'x': {'format': 'dd MMM yyyy'}
    },
    'fill': {
      'type': 'gradient',
      'gradient': {
        'shadeIntensity': 1,
        'opacityFrom': 0.7,
        'opacityTo': 0.9,
        'stops': [0, 100],
      },
    },
    'annotations': {
      'yaxis': [
        {
          'y': 30,
          'borderColor': '#999',
          'label': {
            'text': 'Support',
            'style': {'color': '#fff', 'background': '#00E396'},
          },
        }
      ],
      'xaxis': [
        {
          'x': 1352847600000, // 14 Nov 2012
          'borderColor': '#999',
          'label': {
            'text': 'Rally',
            'style': {'color': '#fff', 'background': '#775DD0'},
          },
        }
      ],
    },
  }).copyWith(fontFamily: 'Inter');

  void _range(String id, String from, String to) {
    setState(() => _active = id);
    _controller.zoomX(_ms(from).toDouble(), _ms(to).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final buttons = <(String, VoidCallback)>[
      ('1M', () => _range('1M', '2013-01-28', '2013-02-27')),
      ('6M', () => _range('6M', '2012-09-27', '2013-02-27')),
      ('1Y', () => _range('1Y', '2012-02-27', '2013-02-27')),
      ('YTD', () => _range('YTD', '2013-01-01', '2013-02-27')),
      ('ALL', () => _range('ALL', '2012-01-23', '2013-02-27')),
    ];

    // Embeddable card content (no Scaffold): the range buttons plus the
    // zoomable area chart. Lives inline in the main gallery grid.
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          children: [
            for (final (id, cb) in buttons)
              _RangeButton(
                label: id,
                active: _active == id,
                onTap: cb,
              ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ApexChart(
            options: _options,
            controller: _controller,
          ),
        ),
      ],
    );
  }
}

class _RangeButton extends StatelessWidget {
  const _RangeButton({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: active ? const Color(0xFF008FFB) : Colors.transparent,
        foregroundColor: active ? Colors.white : const Color(0xFF373D3F),
        minimumSize: const Size(44, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Text(label),
    );
  }
}
