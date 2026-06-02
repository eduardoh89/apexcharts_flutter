import 'package:flutter/widgets.dart';

import 'chart_hit.dart';

/// A faithful reproduction of ApexCharts' default (light) tooltip box.
///
/// ApexCharts renders its tooltip as a DOM element, so the native equivalent
/// is a Flutter widget positioned over the chart. Visual spec ported verbatim
/// from `apexcharts.css` (`.apexcharts-tooltip.apexcharts-theme-light`):
///   * `border-radius: 5px`
///   * `border: 1px solid #e3e3e3`
///   * `background: rgba(255,255,255,.96)`
///   * `box-shadow: 2px 2px 6px -4px #999`
///   * `overflow: hidden`  (so the title bar's background fills the rounded top)
///   * title: padding 6px, font-size 15, background `#eceff1`,
///     `border-bottom: 1px solid #ddd`
///   * series row: padding `0 10px` (4px bottom on the last), 14px text,
///     16px marker, value `font-weight: 600`
class TooltipOverlay extends StatelessWidget {
  const TooltipOverlay({super.key, required this.hit, required this.fontFamily});

  final ChartHit hit;
  final String? fontFamily;

  static const Color _bg = Color(0xF5FFFFFF); // rgba(255,255,255,.96)
  static const Color _border = Color(0xFFE3E3E3);
  static const Color _titleBg = Color(0xFFECEFF1);
  static const Color _titleBorder = Color(0xFFDDDDDD);
  static const Color _text = Color(0xFF373D3F);

  @override
  Widget build(BuildContext context) {
    // IntrinsicWidth gives the Column a bounded width (the widest child) even
    // when the surrounding Positioned hands down unbounded constraints, so the
    // title bar can stretch across the full tooltip width without asserting.
    return IntrinsicWidth(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: _border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66999999), // 2px 2px 6px -4px #999 (approx)
              blurRadius: 4,
              spreadRadius: -2,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: ClipRRect(
          // overflow: hidden — clip the title bar to the rounded corners.
          borderRadius: BorderRadius.circular(5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hit.title.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  decoration: const BoxDecoration(
                    color: _titleBg,
                    border: Border(
                      bottom: BorderSide(color: _titleBorder),
                    ),
                  ),
                  child: Text(
                    hit.title,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _text,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final row in hit.rows) _row(row),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(TooltipSeriesValue row) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: row.color,
              shape: BoxShape.circle,
            ),
          ),
          Text(
            '${row.seriesName}: ',
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 13,
              color: _text,
            ),
          ),
          Text(
            row.formattedValue,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 13,
              fontWeight: row.highlighted ? FontWeight.w700 : FontWeight.w600,
              color: _text,
            ),
          ),
        ],
      ),
    );
  }
}
