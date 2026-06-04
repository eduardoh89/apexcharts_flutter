# Changelog

## 0.1.2

- Performance: hovering a dense chart no longer repaints the whole chart. The
  crosshair, active markers and drag-select rectangle now live in their own
  overlay layer, so a pointer move repaints only that cheap layer instead of
  re-laying-out the grid labels and rebuilding the series spline every frame.
- Performance: axis/legend/data-label text layout is now cached (keyed by text +
  style), so the repeated `TextPainter.layout()` cost during mount/pan/zoom
  animations is paid once per unique label rather than every frame.

## 0.1.1

- Fix a freeze on repeated zoom for charts with `zoom.autoScaleYaxis` (e.g. the
  area-datetime demo): `getGCD`/`mod` now match ApexCharts' precision-capped
  scaling (`p = 7`), so FP-dirty axis ranges no longer make `niceScale` stall
  for seconds. Worst case dropped from ~35s to <2ms per call.
- Add chart screenshots (README gallery + pub.dev screenshots carousel).
- Example gallery: the interactive area-datetime zoom/pan demo is now a card on
  the main page instead of a separate route.

## 0.1.0

Initial release — a native Flutter/Dart port of ApexCharts v4.7.0 (the last MIT
release), rendered on `CustomPainter`/`Canvas` with **zero runtime
dependencies** (no WebView, no JS engine). Runs on every Flutter platform:
Android, iOS, web, Windows, macOS and Linux.

### Chart types (13)

- Line, area (straight / smooth / stepline), with markers and gradient fills
- Bar — grouped, stacked, and horizontal
- Pie and donut
- Scatter and bubble
- Range bar / timeline (Gantt)
- Candlestick / OHLC
- Radar (spider)
- Radial bar / gauge
- Heatmap
- Treemap (squarified layout)

### Interactivity

- Tooltips on every chart type (shared and intersect modes), including heatmap,
  treemap and radar
- Crosshair and active markers
- Drag- and wheel-zoom with a toolbar, smooth path-morph transitions
- Y-axis that eases (no discrete jumps) while panning when `autoScaleYaxis` is on
- Mount/entrance animations

### Axes & scales

- Category, datetime and numeric x-axes
- Linear and logarithmic y-axes, "nice" tick selection
- Value formatters and axis titles

### Method

Every visual/numeric decision is traced to the upstream ApexCharts v4.7.0
source and verified against the real library rendered headless with Puppeteer
(golden-image diffing). See `NOTICE` for the exact upstream tag and commit.
