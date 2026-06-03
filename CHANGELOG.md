# Changelog

## 0.1.0

Initial release — a native Flutter/Dart port of ApexCharts v4.7.0 (the last MIT
release), rendered on `CustomPainter`/`Canvas` with **zero runtime
dependencies** (no WebView, no JS engine). Runs on macOS, web, Android, Windows
and iOS.

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
