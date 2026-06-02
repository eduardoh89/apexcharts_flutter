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
import 'modules/annotation_renderer.dart';
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
  const ApexChart({
    super.key,
    required this.options,
    this.enableTooltip = true,
    this.controller,
  });

  /// Convenience constructor from a raw ApexCharts `options` map.
  ApexChart.fromJson(
    Map<String, dynamic> json, {
    super.key,
    this.enableTooltip = true,
    this.controller,
  }) : options = ApexOptions.fromJson(json);

  final ApexOptions options;

  /// When false the chart is static (no hover tooltip / crosshair).
  final bool enableTooltip;

  /// Optional imperative controller exposing `zoomX` / `resetZoom`, the
  /// apex_dart analogue of ApexCharts' `chart.zoomX(...)` API.
  final ApexChartController? controller;

  @override
  State<ApexChart> createState() => _ApexChartState();
}

/// Imperative handle for an [ApexChart], mirroring ApexCharts' instance API.
///
/// ```dart
/// final c = ApexChartController();
/// ApexChart(options: o, controller: c);
/// // later, from a button:
/// c.zoomX(startEpochMs, endEpochMs);
/// ```
class ApexChartController {
  _ApexChartState? _state;
  void _attach(_ApexChartState s) => _state = s;
  void _detach(_ApexChartState s) {
    if (identical(_state, s)) _state = null;
  }

  /// Zoom the x-axis to the given domain range (epoch ms for datetime charts,
  /// or data-point index otherwise).
  void zoomX(double min, double max) => _state?._applyWindow(min, max);

  /// Restore the full extent.
  void resetZoom() => _state?._resetZoom();
}

class _ApexChartState extends State<ApexChart>
    with TickerProviderStateMixin {
  // Geometry captured during the last paint so hit-testing matches exactly.
  CartesianLayout? _lastLayout;
  Size _lastSize = Size.zero;

  ChartHit? _hit;

  // Active toolbar interaction mode (selection-zoom vs. pan-the-axis).
  ZoomMode _mode = ZoomMode.selectionZoom;

  // Mount animation (0 → 1). Static when animations are disabled.
  late final AnimationController _anim;

  // Zoom-transition animation: morphs the chart between two x-windows when the
  // view changes (ApexCharts `dynamicAnimation`, default 350ms). We keep the
  // *from* and *to* windows and let the painter build + lerp their full layouts
  // (x AND y bounds together) — the path-morph approach, see [_onZoomTick].
  late final AnimationController _zoomAnim;
  XWindow? _zoomFrom;
  XWindow? _zoomTo;
  double _zoomT = 1;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.options.animations.speedMs),
    );
    _zoomAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..addListener(_onZoomTick);
    if (widget.options.animations.enabled) {
      _anim.forward();
    } else {
      _anim.value = 1;
    }
    // Initial zoom window from xaxis.min / xaxis.max.
    final o = widget.options;
    if (o.xMin != null || o.xMax != null) {
      _window = XWindow(
        o.xMin ?? double.negativeInfinity,
        o.xMax ?? double.infinity,
      );
    }
    // Expose imperative zoom to an optional controller.
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(covariant ApexChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _anim.dispose();
    _zoomAnim.dispose();
    super.dispose();
  }

  // Current x-zoom window in domain units; null = full extent.
  XWindow? _window;

  /// Drive the zoom-transition tween. We only need the eased progress here; the
  /// painter does the actual morph by building the *from* and *to* layouts and
  /// lerping them in pixel space (see [CartesianLayout.lerp]). Driving the morph
  /// from full layouts — instead of recomputing `niceScale` per frame — is what
  /// keeps the y-axis moving smoothly in lock-step with x (ApexCharts
  /// `Animations.morphSVG`) rather than snapping in discrete "nice" steps.
  void _onZoomTick() {
    setState(() => _zoomT = Curves.easeInOut.transform(_zoomAnim.value));
  }

  /// Animate the visible window from its current extent to [next] (null = full
  /// extent), then settle on it. Skips the tween when mount animations are off.
  void _animateWindowTo(XWindow? next) {
    final layout = _lastLayout;
    if (layout == null || !widget.options.animations.enabled) {
      setState(() => _window = next);
      return;
    }
    _zoomFrom = _window ?? XWindow(layout.xDomainMin, layout.xDomainMax);
    _zoomTo = next ?? XWindow(layout.xDomainMin, layout.xDomainMax);
    _window = next;
    _zoomT = 0;
    _zoomAnim
      ..reset()
      ..forward();
  }

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
    _animateWindowTo(
      XWindow(loDom, hiDom).clampTo(layout.xDomainMin, layout.xDomainMax),
    );
  }

  // ---- Pan handlers (drag the visible window, ApexCharts pan mode) ----

  double? _panLastX;

  void _onPanStart(double localX) {
    if (!_zoomEnabled) return;
    _panLastX = localX;
    setState(() => _hit = null);
  }

  void _onPanUpdate(double localX) {
    final layout = _lastLayout;
    final last = _panLastX;
    if (layout == null || last == null) return;
    // Convert the pixel delta into a domain delta and shift the window,
    // clamped to the data extent (panning never reveals empty space).
    final curMin = _window?.min ?? layout.xDomainMin;
    final curMax = _window?.max ?? layout.xDomainMax;
    final span = curMax - curMin;
    final domainPerPx = span / layout.plotRect.width;
    final dxDom = (localX - last) * domainPerPx;
    _panLastX = localX;
    final next = XWindow(curMin - dxDom, curMax - dxDom)
        .clampTo(layout.xDomainMin, layout.xDomainMax);
    setState(() => _window = next);
  }

  void _onPanEnd() => _panLastX = null;

  void _onWheel(PointerScrollEvent e) {
    if (!_zoomEnabled) return;
    final plot = _lastLayout!.plotRect;
    final focusT =
        ((e.localPosition.dx - plot.left) / plot.width).clamp(0.0, 1.0);
    // Gentle per-notch factor (<1 zooms in, >1 out). Trackpads fire many small
    // events, so we scale the factor by the (clamped) delta magnitude instead
    // of applying a hard 0.5x/1.5x each time, which felt jumpy.
    final double mag = (e.scrollDelta.dy.abs() / 120).clamp(0.15, 1.0);
    final double factor =
        e.scrollDelta.dy < 0 ? 1 - 0.25 * mag : 1 + 0.25 * mag;
    _zoomBy(factor, focusT);
  }

  /// Scale the current x-window by [factor] about [focusT] (0..1 across the
  /// plot). factor<1 zooms in, >1 zooms out. [animate] tweens the transition
  /// (toolbar buttons); wheel zoom sets it directly to stay responsive.
  void _zoomBy(double factor, double focusT, {bool animate = false}) {
    final layout = _lastLayout;
    if (layout == null) return;
    final curMin = _window?.min ?? layout.xDomainMin;
    final curMax = _window?.max ?? layout.xDomainMax;
    final span = curMax - curMin;
    if (span <= 0) return;

    final focusDom = curMin + focusT * span;
    final newSpan = span * factor;
    final newMin = focusDom - focusT * newSpan;
    final newMax = focusDom + (1 - focusT) * newSpan;

    final next = XWindow(newMin, newMax)
        .clampTo(layout.xDomainMin, layout.xDomainMax);
    // If clamping pinned us back to the full domain, treat as un-zoomed.
    final full = next.min <= layout.xDomainMin + 1e-9 &&
        next.max >= layout.xDomainMax - 1e-9;
    final target = full ? null : next;
    if (animate) {
      _animateWindowTo(target);
    } else {
      setState(() => _window = target);
    }
  }

  void _zoomInCenter() => _zoomBy(0.6, 0.5, animate: true);
  void _zoomOutCenter() => _zoomBy(1 / 0.6, 0.5, animate: true);

  void _resetZoom() {
    if (_window != null) _animateWindowTo(null);
  }

  /// Apply an explicit x-window (used by [ApexChartController.zoomX]).
  void _applyWindow(double min, double max) {
    final layout = _lastLayout;
    final next = layout == null
        ? XWindow(min, max)
        : XWindow(min, max).clampTo(layout.xDomainMin, layout.xDomainMax);
    _animateWindowTo(next);
  }

  bool get _isZoomed {
    final layout = _lastLayout;
    if (_window == null || layout == null) return false;
    return _window!.min > layout.xDomainMin + 1e-9 ||
        _window!.max < layout.xDomainMax - 1e-9;
  }

  @override
  Widget build(BuildContext context) {
    // While a zoom transition runs, hand the painter both windows + progress so
    // it can morph the layout in pixel space; otherwise just the settled window.
    final bool morphing = _zoomAnim.isAnimating && _zoomFrom != null;
    final painter = _ApexChartPainter(
      widget.options,
      hit: _hit,
      window: _window,
      morphFrom: morphing ? _zoomFrom : null,
      morphTo: morphing ? _zoomTo : null,
      morphT: morphing ? _zoomT : 1,
      selectStartX: _selectStartX,
      selectCurrentX: _selectCurrentX,
      animation: _anim,
      onLayout: (layout, size) {
        _lastLayout = layout;
        _lastSize = size;
      },
    );

    Widget chart = CustomPaint(painter: painter, size: Size.infinite);

    // Horizontal drag drives selection-zoom or panning depending on the active
    // toolbar mode (ApexCharts' zoomEnabled vs panEnabled).
    if (_isCartesian && widget.options.zoom.enabled) {
      final bool panning = _mode == ZoomMode.pan;
      chart = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) => panning
            ? _onPanStart(d.localPosition.dx)
            : _onSelectStart(d.localPosition.dx),
        onHorizontalDragUpdate: (d) => panning
            ? _onPanUpdate(d.localPosition.dx)
            : _onSelectUpdate(d.localPosition.dx),
        onHorizontalDragEnd: (_) => panning ? _onPanEnd() : _onSelectEnd(),
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
                  mode: _mode,
                  onZoomIn: _zoomInCenter,
                  onZoomOut: _zoomOutCenter,
                  onReset: _resetZoom,
                  onSelectMode: (m) => setState(() => _mode = m),
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
    this.morphFrom,
    this.morphTo,
    this.morphT = 1,
    this.selectStartX,
    this.selectCurrentX,
    required this.animation,
    required this.onLayout,
  }) : super(repaint: animation);

  final ApexOptions options;
  final ChartHit? hit;
  final XWindow? window;

  /// Zoom-transition endpoints + eased progress. When [morphFrom]/[morphTo] are
  /// set the cartesian layout is the pixel-space lerp of the two endpoint
  /// layouts (ApexCharts path-morph), so x and y move together.
  final XWindow? morphFrom;
  final XWindow? morphTo;
  final double morphT;

  final double? selectStartX;
  final double? selectCurrentX;
  final Animation<double> animation;
  final _LayoutCallback onLayout;

  /// Eased mount progress (0..1).
  double get progress =>
      Curves.easeOutCubic.transform(animation.value.clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    switch (options.type) {
      case ApexChartType.line:
      case ApexChartType.area:
        _paintCartesian(canvas, size, _CartesianKind.line);
      case ApexChartType.bar:
        _paintCartesian(canvas, size, _CartesianKind.bar);
      case ApexChartType.scatter:
      case ApexChartType.bubble:
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
    CartesianLayout build(XWindow? w) => CartesianLayout.compute(
          options,
          size,
          legendBottom: pos == ApexLegendPosition.bottom ? legendH : 0,
          legendTop: pos == ApexLegendPosition.top ? legendH : 0,
          legendLeft: pos == ApexLegendPosition.left ? legendW : 0,
          legendRight: pos == ApexLegendPosition.right ? legendW : 0,
          xWindow: w,
        );

    // Mid-transition: build the start + target layouts (each with its own nice
    // y-scale) and lerp them, so both axes animate continuously together.
    if (morphFrom != null && morphTo != null && morphT < 1) {
      return CartesianLayout.lerp(build(morphFrom), build(morphTo), morphT);
    }
    return build(window);
  }

  void _paintCartesian(Canvas canvas, Size size, _CartesianKind kind) {
    final layout = _layoutFor(size);
    onLayout(layout, size);

    // Grid + axes draw unclipped (labels live in the gutters).
    GridRenderer.paint(canvas, layout, options);

    final double t = progress;

    // Series are clipped to the plot rect so zoomed-out-of-view data does not
    // overflow into the axis gutters (matches ApexCharts' clip-path).
    canvas.save();
    canvas.clipRect(layout.plotRect.inflate(1));

    // Line/area: reveal left→right (ApexCharts "pen-stroke" draw). Bars grow
    // from the baseline via a vertical scale about the zero line.
    if (kind == _CartesianKind.line && t < 1) {
      final revealW = layout.plotRect.left + layout.plotRect.width * t;
      canvas.clipRect(Rect.fromLTRB(
        layout.plotRect.left - 1,
        layout.plotRect.top - 2,
        revealW,
        layout.plotRect.bottom + 2,
      ));
    }

    if (kind == _CartesianKind.bar && t < 1) {
      final baseY = layout.yToPixel(0);
      canvas.translate(0, baseY);
      canvas.scale(1, t);
      canvas.translate(0, -baseY);
    }

    switch (kind) {
      case _CartesianKind.line:
        LineChartRenderer.paint(canvas, layout, options);
      case _CartesianKind.bar:
        BarChartRenderer.paint(canvas, layout, options);
      case _CartesianKind.scatter:
        ScatterChartRenderer.paint(canvas, layout, options);
    }
    canvas.restore();

    // Annotations (guide lines + label pills) draw on top of the series but
    // are clipped horizontally to the plot so x-lines don't escape the area.
    if (t >= 0.99) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(
        layout.plotRect.left,
        0,
        layout.plotRect.right,
        size.height,
      ));
      AnnotationRenderer.paint(canvas, layout, options);
      canvas.restore();
    }

    // Labels / hover overlays draw only once the entrance settles, so they
    // don't flicker mid-animation.
    if (t >= 0.99) {
      canvas.save();
      canvas.clipRect(layout.plotRect.inflate(1));
      DataLabelsRenderer.paint(canvas, layout, options);
      if (hit != null) {
        HoverPainter.paint(canvas, hit!, layout);
      }
      canvas.restore();
    }

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
    final double t = progress;
    if (t < 1) {
      // Scale-up entrance from the chart center.
      final center = Offset(size.width / 2, size.height / 2);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(t);
      canvas.translate(-center.dx, -center.dy);
      PieChartRenderer.paint(canvas, size, options);
      canvas.restore();
    } else {
      PieChartRenderer.paint(canvas, size, options);
    }
    LegendRenderer.paint(canvas, size, options);
    if (t >= 0.99 && hit != null) {
      HoverPainter.paint(canvas, hit!, null);
    }
  }

  @override
  bool shouldRepaint(covariant _ApexChartPainter oldDelegate) =>
      oldDelegate.options != options ||
      oldDelegate.hit != hit ||
      oldDelegate.window != window ||
      oldDelegate.morphFrom != morphFrom ||
      oldDelegate.morphTo != morphTo ||
      oldDelegate.morphT != morphT ||
      oldDelegate.selectStartX != selectStartX ||
      oldDelegate.selectCurrentX != selectCurrentX ||
      oldDelegate.animation != animation;
}

enum _CartesianKind { line, bar, scatter }
