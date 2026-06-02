import 'package:flutter/widgets.dart';

import 'charts/bar_chart.dart';
import 'charts/line_chart.dart';
import 'charts/pie_chart.dart';
import 'charts/scatter_chart.dart';
import 'interaction/cartesian_hit_tester.dart';
import 'interaction/chart_hit.dart';
import 'interaction/hover_painter.dart';
import 'interaction/pie_hit_tester.dart';
import 'interaction/tooltip_overlay.dart';
import 'modules/cartesian_layout.dart';
import 'modules/data_labels_renderer.dart';
import 'modules/grid_renderer.dart';
import 'modules/legend_renderer.dart';
import 'options/apex_options.dart';

/// The public chart widget — the apex_dart analogue of `new ApexCharts(el, opts)`.
///
/// Renders natively via [CustomPaint] and tracks the pointer to show an
/// ApexCharts-style tooltip (a positioned widget overlay) plus a crosshair and
/// active markers, matching the library's default interactivity.
class ApexChart extends StatefulWidget {
  const ApexChart({super.key, required this.options, this.enableTooltip = true});

  /// Convenience constructor from a raw ApexCharts `options` map.
  ApexChart.fromJson(
    Map<String, dynamic> json, {
    super.key,
    this.enableTooltip = true,
  }) : options = ApexOptions.fromJson(json);

  final ApexOptions options;

  /// When false the chart is static (no hover tooltip / crosshair).
  final bool enableTooltip;

  @override
  State<ApexChart> createState() => _ApexChartState();
}

class _ApexChartState extends State<ApexChart> {
  // Geometry captured during the last paint so hit-testing matches exactly.
  CartesianLayout? _lastLayout;
  Size _lastSize = Size.zero;

  ChartHit? _hit;
  Offset _pointer = Offset.zero;

  bool get _isCartesian =>
      widget.options.type.isCartesian;

  void _onHover(Offset local) {
    if (!widget.enableTooltip) return;
    ChartHit? hit;
    if (_isCartesian && _lastLayout != null) {
      hit = CartesianHitTester(layout: _lastLayout!, options: widget.options)
          .hitTest(local);
    } else if (widget.options.type.isRadial) {
      hit = PieHitTester(size: _lastSize, options: widget.options)
          .hitTest(local);
    }
    if (hit != _hit || local != _pointer) {
      setState(() {
        _hit = hit;
        _pointer = local;
      });
    }
  }

  void _clear() {
    if (_hit != null) setState(() => _hit = null);
  }

  @override
  Widget build(BuildContext context) {
    final painter = _ApexChartPainter(
      widget.options,
      hit: _hit,
      onLayout: (layout, size) {
        _lastLayout = layout;
        _lastSize = size;
      },
    );

    return MouseRegion(
      onHover: (e) => _onHover(e.localPosition),
      onExit: (_) => _clear(),
      child: Listener(
        onPointerDown: (e) => _onHover(e.localPosition),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: painter, size: Size.infinite),
            ),
            if (_hit != null)
              _PositionedTooltip(
                hit: _hit!,
                containerSize: _lastSize,
                fontFamily: widget.options.fontFamily,
              ),
          ],
        ),
      ),
    );
  }
}

/// Positions the [TooltipOverlay] near the focused datum, flipping sides so it
/// stays within the chart bounds (ApexCharts' tooltip auto-positioning).
class _PositionedTooltip extends StatelessWidget {
  const _PositionedTooltip({
    required this.hit,
    required this.containerSize,
    required this.fontFamily,
  });

  final ChartHit hit;
  final Size containerSize;
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    // Estimate tooltip size to keep it on-screen; the real size is measured by
    // the widget, this is just for placement clamping.
    const double approxW = 160;
    final double approxH = 28.0 + hit.rows.length * 20 + 12;

    double left = hit.anchor.dx + 12;
    if (left + approxW > containerSize.width) {
      left = hit.anchor.dx - approxW - 12;
    }
    if (left < 0) left = 4;

    double top = hit.anchor.dy - approxH - 8;
    if (top < 0) top = hit.anchor.dy + 12;
    if (top + approxH > containerSize.height) {
      top = (containerSize.height - approxH).clamp(0, containerSize.height);
    }

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: TooltipOverlay(hit: hit, fontFamily: fontFamily),
      ),
    );
  }
}

typedef _LayoutCallback = void Function(CartesianLayout? layout, Size size);

class _ApexChartPainter extends CustomPainter {
  _ApexChartPainter(this.options, {this.hit, required this.onLayout});

  final ApexOptions options;
  final ChartHit? hit;
  final _LayoutCallback onLayout;

  @override
  void paint(Canvas canvas, Size size) {
    switch (options.type) {
      case ApexChartType.line:
      case ApexChartType.area:
        _paintCartesian(canvas, size, _CartesianKind.line);
      case ApexChartType.bar:
        _paintCartesian(canvas, size, _CartesianKind.bar);
      case ApexChartType.scatter:
        _paintCartesian(canvas, size, _CartesianKind.scatter);
      case ApexChartType.pie:
      case ApexChartType.donut:
        _paintPie(canvas, size);
      case ApexChartType.radialBar:
      case ApexChartType.heatmap:
        onLayout(null, size);
        break;
    }
  }

  CartesianLayout _layoutFor(Size size) {
    final pos = options.legend.position;
    final legendH = LegendRenderer.reservedHeight(options);
    final legendW = LegendRenderer.reservedWidth(options);
    return CartesianLayout.compute(
      options,
      size,
      legendBottom: pos == ApexLegendPosition.bottom ? legendH : 0,
      legendTop: pos == ApexLegendPosition.top ? legendH : 0,
      legendLeft: pos == ApexLegendPosition.left ? legendW : 0,
      legendRight: pos == ApexLegendPosition.right ? legendW : 0,
    );
  }

  void _paintCartesian(Canvas canvas, Size size, _CartesianKind kind) {
    final layout = _layoutFor(size);
    onLayout(layout, size);

    GridRenderer.paint(canvas, layout, options);
    switch (kind) {
      case _CartesianKind.line:
        LineChartRenderer.paint(canvas, layout, options);
      case _CartesianKind.bar:
        BarChartRenderer.paint(canvas, layout, options);
      case _CartesianKind.scatter:
        ScatterChartRenderer.paint(canvas, layout, options);
    }
    DataLabelsRenderer.paint(canvas, layout, options);
    LegendRenderer.paint(canvas, size, options);

    if (hit != null) {
      HoverPainter.paint(canvas, hit!, layout);
    }
  }

  void _paintPie(Canvas canvas, Size size) {
    onLayout(null, size);
    PieChartRenderer.paint(canvas, size, options);
    LegendRenderer.paint(canvas, size, options);
    if (hit != null) {
      HoverPainter.paint(canvas, hit!, null);
    }
  }

  @override
  bool shouldRepaint(covariant _ApexChartPainter oldDelegate) =>
      oldDelegate.options != options || oldDelegate.hit != hit;
}

enum _CartesianKind { line, bar, scatter }
