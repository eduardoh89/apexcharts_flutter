import 'package:apexcharts_flutter/apexcharts_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const size = Size(600, 360);
  // autoScaleYaxis:true so the y-axis rescales to the visible window — these
  // tests exercise that path (the morph/lerp machinery). With it off (the
  // ApexCharts default) the y-axis stays fixed at the full extent.
  final options = ApexOptions.fromJson({
    'chart': {
      'type': 'line',
      'zoom': {'enabled': true, 'autoScaleYaxis': true}
    },
    'colors': ['#008FFB'],
    'series': [
      {
        'name': 'A',
        'data': [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
      }
    ],
    'xaxis': {
      'categories': [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    },
  });

  group('XWindow', () {
    test('clampTo keeps within domain and enforces min span', () {
      const w = XWindow(-5, 100);
      final c = w.clampTo(0, 9);
      expect(c.min, greaterThanOrEqualTo(0));
      expect(c.max, lessThanOrEqualTo(9));
    });

    test('collapsed window expands to minimum span', () {
      const w = XWindow(4, 4);
      final c = w.clampTo(0, 9);
      expect(c.max, greaterThan(c.min));
    });
  });

  group('CartesianLayout zoom window', () {
    test('full view maps index 0 to left, last to right', () {
      final layout = CartesianLayout.compute(options, size);
      expect(layout.xCategoryToPixel(0), closeTo(layout.plotRect.left, 0.01));
      expect(layout.xCategoryToPixel(9), closeTo(layout.plotRect.right, 0.01));
      expect(layout.isZoomed, isFalse);
    });

    test('zoomed window stretches the sub-range across the plot', () {
      final layout = CartesianLayout.compute(
        options,
        size,
        xWindow: const XWindow(2, 4),
      );
      expect(layout.isZoomed, isTrue);
      // Index 2 now sits at the left edge, index 4 at the right edge.
      expect(layout.xCategoryToPixel(2), closeTo(layout.plotRect.left, 0.5));
      expect(layout.xCategoryToPixel(4), closeTo(layout.plotRect.right, 0.5));
    });

    test('y-axis rescales to the visible window (autoScaleYaxis on)', () {
      // Full view: max 100. Window 0..2 only sees values 10,20,30 → niceMax<100.
      final full = CartesianLayout.compute(options, size);
      final zoomed = CartesianLayout.compute(
        options,
        size,
        xWindow: const XWindow(0, 2),
      );
      expect(zoomed.yMax, lessThan(full.yMax));
    });

    test('y-axis stays fixed when autoScaleYaxis is off (ApexCharts default)',
        () {
      // Same data but without autoScaleYaxis: zooming must NOT move the y-axis,
      // so it never snaps in discrete steps while panning.
      final fixed = ApexOptions.fromJson({
        'chart': {
          'type': 'line',
          'zoom': {'enabled': true}
        },
        'colors': ['#008FFB'],
        'series': [
          {
            'name': 'A',
            'data': [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
          }
        ],
        'xaxis': {
          'categories': [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
        },
      });
      final full = CartesianLayout.compute(fixed, size);
      final zoomed = CartesianLayout.compute(
        fixed,
        size,
        xWindow: const XWindow(0, 2),
      );
      expect(zoomed.yMin, full.yMin);
      expect(zoomed.yMax, full.yMax);
    });

    test('yOverride forces an explicit (animated) y range', () {
      final layout = CartesianLayout.compute(
        options,
        size,
        xWindow: const XWindow(0, 2),
        yOverride: const YBounds(0, 200, [0, 50, 100, 150, 200]),
      );
      expect(layout.yMin, 0);
      expect(layout.yMax, 200);
      expect(layout.yTicks, [0, 50, 100, 150, 200]);
    });

    test('pixelToXDomain is the inverse of xCategoryToPixel', () {
      final layout = CartesianLayout.compute(
        options,
        size,
        xWindow: const XWindow(1, 6),
      );
      final px = layout.xCategoryToPixel(3);
      expect(layout.pixelToXDomain(px), closeTo(3, 0.01));
    });
  });

  group('CartesianLayout.lerp zoom morph', () {
    // Replicates ApexCharts' path-morph: x and y bounds must both move
    // continuously between the start and target layouts, so the y-axis can't
    // snap mid-transition.
    final full = CartesianLayout.compute(options, size);
    final target = CartesianLayout.compute(
      options,
      size,
      xWindow: const XWindow(0, 2),
    );

    test('endpoints are exact at t=0 and t=1', () {
      final at0 = CartesianLayout.lerp(full, target, 0);
      final at1 = CartesianLayout.lerp(full, target, 1);
      expect(at0.yMax, closeTo(full.yMax, 1e-9));
      expect(at0.xViewMax, closeTo(full.xViewMax, 1e-9));
      expect(at1.yMax, closeTo(target.yMax, 1e-9));
      expect(at1.xViewMax, closeTo(target.xViewMax, 1e-9));
    });

    test('y-bound moves monotonically with progress (no snap)', () {
      // target.yMax < full.yMax (zoomed window sees smaller values), so the
      // interpolated yMax must decrease smoothly as t grows.
      expect(target.yMax, lessThan(full.yMax));
      final mid = CartesianLayout.lerp(full, target, 0.5);
      expect(mid.yMax, lessThan(full.yMax));
      expect(mid.yMax, greaterThan(target.yMax));
      // Exactly halfway between the two endpoints.
      expect(mid.yMax, closeTo((full.yMax + target.yMax) / 2, 1e-9));
    });

    test('x and y advance by the same fraction at t=0.5', () {
      final mid = CartesianLayout.lerp(full, target, 0.5);
      final xFrac =
          (full.xViewMax - mid.xViewMax) / (full.xViewMax - target.xViewMax);
      final yFrac = (full.yMax - mid.yMax) / (full.yMax - target.yMax);
      expect(xFrac, closeTo(yFrac, 1e-6));
    });
  });

  group('zoom defaults by chart type', () {
    test('line/area default zoom enabled, bar/scatter off', () {
      ApexOptions parse(String t) => ApexOptions.fromJson({
            'chart': {'type': t},
            'series': t == 'pie'
                ? [1, 2]
                : [
                    {
                      'name': 'A',
                      'data': [1, 2, 3]
                    }
                  ],
            if (t == 'pie') 'labels': ['a', 'b'],
          });
      expect(parse('line').zoom.enabled, isTrue);
      expect(parse('area').zoom.enabled, isTrue);
      expect(parse('bar').zoom.enabled, isFalse);
    });

    test('explicit zoom.enabled overrides default', () {
      final o = ApexOptions.fromJson({
        'chart': {
          'type': 'bar',
          'zoom': {'enabled': true}
        },
        'series': [
          {
            'name': 'A',
            'data': [1, 2, 3]
          }
        ],
      });
      expect(o.zoom.enabled, isTrue);
    });
  });

  group('mouse wheel over a zoomable chart', () {
    // Reproduces a reported bug: scrolling the mouse wheel while hovering a
    // chart embedded in a scrollable dashboard zoomed the chart AND scrolled
    // the page underneath it at the same time. ApexChart's Listener now
    // claims the PointerScrollEvent via GestureBinding's shared resolver
    // instead of handling it directly — only the first registrant (the
    // chart, being hit-tested before its ancestor Scrollable) should run.
    testWidgets(
      'zooms the chart and leaves an ancestor Scrollable untouched',
      (tester) async {
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  children: [
                    SizedBox(
                      width: 480,
                      height: 320,
                      child: ApexChart(options: options),
                    ),
                    // Enough extra height to make the page itself scrollable.
                    const SizedBox(height: 2000),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1200));

        expect(scrollController.offset, 0);
        final chartCenter = tester.getCenter(find.byType(ApexChart));

        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: chartCenter,
            scrollDelta: const Offset(0, 300),
          ),
        );
        await tester.pump();

        // The chart claimed the signal — the page must not have moved.
        expect(scrollController.offset, 0);
      },
    );

    // Reproduces a second, worse regression the fix above introduced: the
    // Listener wrapped EVERY chart type unconditionally, so a pie/bar/radar/
    // heatmap chart — anything without zoom — still won the resolver claim
    // and then no-op'd inside _onWheel, silently swallowing the scroll
    // instead of either zooming OR letting the page scroll. Only a chart
    // that can actually use the wheel should ever intercept it.
    Future<void> expectPageScrollsNormally(
      WidgetTester tester,
      ApexOptions chartOptions,
    ) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                children: [
                  SizedBox(
                    width: 480,
                    height: 320,
                    child: ApexChart(options: chartOptions),
                  ),
                  const SizedBox(height: 2000),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1200));

      expect(scrollController.offset, 0);
      final chartCenter = tester.getCenter(find.byType(ApexChart));

      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: chartCenter,
          scrollDelta: const Offset(0, 300),
        ),
      );
      await tester.pump();

      // Nothing claimed the signal — the ancestor Scrollable must have moved.
      expect(scrollController.offset, 300);
    }

    testWidgets(
      'lets the page scroll normally over a non-cartesian chart (pie)',
      (tester) async {
        final pieOptions = ApexOptions.fromJson({
          'chart': {'type': 'pie'},
          'series': [44, 55, 13],
          'labels': ['A', 'B', 'C'],
        });
        await expectPageScrollsNormally(tester, pieOptions);
      },
    );

    testWidgets(
      'lets the page scroll normally over a cartesian chart with zoom disabled (bar)',
      (tester) async {
        final barOptions = ApexOptions.fromJson({
          'chart': {
            'type': 'bar',
            'zoom': {'enabled': false},
          },
          'series': [
            {
              'name': 'A',
              'data': [1, 2, 3],
            },
          ],
          'xaxis': {
            'categories': [0, 1, 2],
          },
        });
        await expectPageScrollsNormally(tester, barOptions);
      },
    );
  });
}
