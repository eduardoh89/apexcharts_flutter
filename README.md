# apex_dart

A **native Flutter/Dart port of [ApexCharts](https://github.com/apexcharts/apexcharts.js) v4.7.0** — the last release published under the MIT license.

`apex_dart` reimplements ApexCharts' rendering on Flutter's `CustomPainter`/
`Canvas` instead of SVG/DOM, so it runs on **macOS, web, Android, Windows and
iOS** with no WebView or JS engine.

> **Why a port and not a wrapper?** ApexCharts is a browser SVG library and
> does not run on Flutter desktop (no macOS WebView). Porting the math + draw
> logic to `CustomPainter` gives identical visuals natively on every platform.

## Licensing

This package is based **exclusively** on ApexCharts **v4.7.0** (MIT). v5+ moved
to a non-MIT dual license and is **not** used here. See [`NOTICE`](NOTICE) and
[`LICENSE`](LICENSE). Original copyright (c) 2018 ApexCharts is retained.

## Porting method (golden-driven)

The port is incremental and validated against the real library:

```
fixture (JSON options)
      │
      ├──► tool/render_reference.mjs ──► ApexCharts v4.7.0 PNG  (reference)
      │
      └──► apex_dart ApexChart widget ─► Flutter golden PNG
                                              │
                                  perceptual diff (tolerance)
```

No module is "done" until its golden matches the ApexCharts reference within a
perceptual tolerance.

## Status

| Phase | Scope | State |
|-------|-------|-------|
| 0 | Fork v4.7.0 + scaffold | ✅ |
| 1 | Visual-diff harness + 6 fixtures | ✅ |
| 2 | Foundation: utils, scales, axes, svg, options | ✅ |
| 3 | Line chart end-to-end (line/area, straight/smooth/step) | ✅ |
| 4 | Bar (grouped) + Pie/Donut | ✅ |
| 5 | area / scatter / stacked / horizontal + zoom/pan + tooltips | ✅ |
| 5b | bubble, rangeBar/timeline, logarithmic axis | ✅ |
| 6 | radialBar/gauge, radar | ✅ |
| 7 | heatmap, candlestick/OHLC, treemap | ✅ |

Remaining backlog: multiple y-axes, tooltip dark theme + `intersect`,
distributed (per-bar/tile) colors, stacked-total labels.

Line charts diff **~7–12%** against the ApexCharts reference; bar/pie/donut
**~25–37%** (higher because solid-fill edges double-count any sub-pixel offset
between the SVG and Skia rasterizers). In all cases the geometry, colours,
y-axis ticks and data labels match the reference — the residual is
anti-aliasing, verifiable via the 3-up diff images in `test/golden/failures/`.

## Layout

```
lib/src/utils/      math, color, range/niceScale  (ported, tested)
lib/src/options/    ApexOptions-equivalent config model
lib/src/svg/        CustomPainter primitives
lib/src/modules/    scales, axes, grid, legend, tooltip, datalabels
lib/src/charts/     line, area, bar, pie/donut, ...
reference/          vendored MIT v4.7.0 source (porting reference, not shipped)
tool/               puppeteer reference renderer + fixtures
test/golden/        reference PNGs + Flutter goldens
```

## Development

```bash
# from the package root
flutter pub get
flutter analyze
flutter test                      # unit + golden tests
flutter test --update-goldens     # regenerate goldens after intentional change

# regenerate ApexCharts reference PNGs (requires node)
cd tool && npm install && node render_reference.mjs
```
