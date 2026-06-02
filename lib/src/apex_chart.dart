import 'package:flutter/gestures.dart';
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
import 'interaction/zoom_toolbar.dart';
import 'modules/cartesian_layout.dart';
import 'modules/data_labels_renderer.dart';
import 'modules/grid_renderer.dart';
import 'modules/legend_renderer.dart';
import 'options/apex_options.dart';

/// The public chart widget — the apex_dart analogue of `new ApexCharts(el, opts)`.
///
/// Renders natively via [CustomPaint] and tracks the pointer to show an
/// ApexCharts-style tooltip plus crosshair/markers. For line/area/scatter it
/// also supports ApexCharts-style **x-zoom**: drag-select a range to zoom in,
/// mouse-wheel to zoom about the cursor, and a reset button to restore.
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

  // Current x-zoom window in domain units; null = full extent.
  XWindow? _window;

  // Active drag-select (zoom) in pixel space.
  double? _selectStartX;
  double? _selectCurrentX;

  bool get _isCartesian => widget.options.type.isCartesian;
  bool get _zoomEnabled =>
      _isCartesian && widget.options.zoom.enabled && _lastLayout != null;

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
    if (hit != _hit) {
      setState(() => _hit = hit);
    }
  }

  void _clearHover() {
    if (_hit != null) setState(() => _hit = null);
  }

  // ---- Zoom / pan handlers ----

  void _onSelectStart(double localX) {
    if (!_zoomEnabled) return;
    final plot = _lastLayout!.plotRect;
    setState(() {
      _selectStartX = localX.clamp(plot.left, plot.right);
      _selectCurrentX = _selectStartX;
      _hit = null;
    });
  }

  void _onSelectUpdate(double localX) {
    if (_selectStartX == null) return;
    final plot = _lastLayout!.plotRect;
    setState(() => _selectCurrentX = localX.clamp(plot.left, plot.right));
  }

  void _onSelectEnd() {
    if (_selectStartX == null || _selectCurrentX == null) {
      _selectStartX = null;
      _selectCurrentX = null;
      return;
    }
    final layout = _lastLayout!;
    final a = _selectStartX!;
    final b = _selectCurrentX!;
    _selectStartX = null;
    _selectCurrentX = null;

    // Ignore tiny drags (treat as click).
    if ((a - b).abs() < 6) {
      setState(() {});
      return;
    }
    final loPx = a < b ? a : b;
    final hiPx = a < b ? b : a;
    final loDom = layout.pixelToXDomain(loPx);
    final hiDom = layout.pixelToXDomain(hiPx);
    setState(() {
      _window = XWindow(loDom, hiDom)
          .clampTo(layout.xDomainMin, layout.xDomainMax);
    });
  }

  void _onWheel(PointerScrollEvent e) {
    if (!_zoomEnabled) return;
    final layout = _lastLayout!;
    final curMin = _window?.min ?? layout.xDomainMin;
    final curMax = _window?.max ?? layout.xDomainMax;
    final totalX = curMax - curMin;
    if (totalX <= 0) return;

    final plot = layout.plotRect;
    final mouseT =
        ((e.localPosition.dx - plot.left) / plot.width).clamp(0.0, 1.0);

    // ApexCharts: zoom-in factor 0.5, zoom-out 1.5, about the cursor.
    double newMin, newMax;
    if (e.scrollDelta.dy < 0) {
      final range = 0.5 * totalX;
      final mid = curMin + mouseT * totalX;
      newMin = mid - range / 2;
      newMax = mid + range / 2;
    } else {
      final range = 1.5 * totalX;
      newMin = curMin - range / 2;
      newMax = curMax + range / 2;
    }
    setState(() {
      _window = XWindow(newMin, newMax)
          .clampTo(layout.xDomainMin, layout.xDomainMax);
    });
  }

  void _resetZoom() {
    if (_window != null) setState(() => _window = null);
  }

  bool get _isZoomed {
    final layout = _lastLayout;
    if (_window == null || layout == null) return false;
    return _window!.min > layout.xDomainMin + 1e-9 ||
        _window!.max < layout.xDomainMax - 1e-9;
  }

  @override
  Widget build(BuildContext context) {
    final painter = _ApexChartPainter(
      widget.options,
      hit: _hit,
      window: _window,
      selectStartX: _selectStartX,
      selectCurrentX: _selectCurrentX,
      onLayout: (layout, size) {
        _lastLayout = layout;
        _lastSize = size;
      },
    );

    Widget chart = CustomPaint(painter: painter, size: Size.infinite);

    // Drag-select zoom is layered via a gesture detector when enabled.
    if (_isCartesian && widget.options.zoom.enabled) {
      chart = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) => _onSelectStart(d.localPosition.dx),
        onHorizontalDragUpdate: (d) => _onSelectUpdate(d.localPosition.dx),
        onHorizontalDragEnd: (_) => _onSelectEnd(),
        child: chart,
      );
    }

    return Listener(
      onPointerSignal: (e) {
        if (e is PointerScrollEvent) _onWheel(e);
      },
      child: MouseRegion(
        onHover: (e) => _onHover(e.localPosition),
        onExit: (_) => _clearHover(),
        child: Stack(
          children: [
            Positioned.fill(child: chart),
            if (_isCartesian &&
                widget.options.zoom.enabled &&
                widget.options.zoom.showToolbar)
              Positioned(
                top: 4,
                right: 8,
                child: ZoomToolbar(
                  isZoomed: _isZoomed,
                  onReset: _resetZoom,
                  fontFamily: widget.options.fontFamily,
                ),
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
  _ApexChartPainter(
    this.options, {
    this.hit,
    this.window,
    this.selectStartX,
    this.selectCurrentX,
    required this.onLayout,
  });

  final ApexOptions options;
  final ChartHit? hit;
  final XWindow? window;
  final double? selectStartX;
  final double? selectCurrentX;
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
      xWindow: window,
    );
  }

  void _paintCartesian(Canvas canvas, Size size, _CartesianKind kind) {
    final layout = _layoutFor(size);
    onLayout(layout, size);

    // Grid + axes draw unclipped (labels live in the gutters).
    GridRenderer.paint(canvas, layout, options);

    // Series are clipped to the plot rect so zoomed-out-of-view data does not
    // overflow into the axis gutters (matches ApexCharts' clip-path).
    canvas.save();
    canvas.clipRect(layout.plotRect.inflate(1));
    switch (kind) {
      case _CartesianKind.line:
        LineChartRenderer.paint(canvas, layout, options);
      case _CartesianKind.bar:
        BarChartRenderer.paint(canvas, layout, options);
      case _CartesianKind.scatter:
        ScatterChartRenderer.paint(canvas, layout, options);
    }
    DataLabelsRenderer.paint(canvas, layout, options);
    if (hit != null) {
      HoverPainter.paint(canvas, hit!, layout);
    }
    canvas.restore();

    LegendRenderer.paint(canvas, size, options);

    // Selection rectangle (drag-to-zoom) — ApexCharts xcrosshairs selection.
    if (selectStartX != null && selectCurrentX != null) {
      final lo = selectStartX! < selectCurrentX! ? selectStartX! : selectCurrentX!;
      final hi = selectStartX! < selectCurrentX! ? selectCurrentX! : selectStartX!;
      final rect = Rect.fromLTRB(lo, layout.plotRect.top, hi, layout.plotRect.bottom);
      canvas.drawRect(
        rect,
        Paint()..color = const Color(0x1A008FFB),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x66008FFB),
      );
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
      oldDelegate.options != options ||
      oldDelegate.hit != hit ||
      oldDelegate.window != window ||
      oldDelegate.selectStartX != selectStartX ||
      oldDelegate.selectCurrentX != selectCurrentX;
}

enum _CartesianKind { line, bar, scatter }
