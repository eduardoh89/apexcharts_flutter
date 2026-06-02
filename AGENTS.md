# AGENTS.md — apex_dart

Guidance for AI agents (and humans) working on **apex_dart**: a native
Flutter/Dart port of **ApexCharts.js v4.7.0** (the last MIT release).

This file is about *how to work in this package*. For the what/why see
[`README.md`](README.md), [`NOTICE`](NOTICE) and [`LICENSE`](LICENSE).

---

## 0. The one rule that matters

> **This is a transpilation, not a reinvention. Never guess behavior — read the
> original ApexCharts source, port it faithfully, then verify against the real
> library by rendering it with Puppeteer.**

Every visual/numeric decision must be traceable to a specific file/line in
`reference/apexcharts-4.7.0-src/`. If you can't point at the upstream code that
justifies a constant, a formula, or a default, you are guessing — stop and go
read the source.

When you fix or add something, the commit message should name the upstream
module it came from (e.g. "ApexCharts `Fill.js` / `Defaults.area()`").

---

## 1. Environment (critical — read before running anything)

This package lives inside the **Revia Portal** monorepo worktree at
`graficos/apex_dart/`. The toolchain is pinned and **not on the PATH** of
non-interactive shells. Use absolute binary paths:

```bash
# Flutter SDK is pinned via FVM (frontend/.fvmrc → 3.38.7, Dart 3.10.7).
# `fvm` is NOT on the PATH here — call the versioned binary directly:
~/fvm/versions/3.38.7/bin/flutter
~/fvm/versions/3.38.7/bin/dart

# Node (for the Puppeteer reference harness):
node    # v22.x, npm 10.x
```

Notes that have bitten us before:
- `timeout(1)` does **not** exist on this macOS. Don't wrap commands in it.
- Always `cd` into `apex_dart/` (this package) before running flutter/dart.
- `reference/`, `example/build/`, `tool/node_modules/`, `example/fonts/` and
  `test/golden/failures/` are **gitignored** — never commit them.
- The pure-Dart engine has **zero runtime dependencies** (`pubspec.yaml`):
  no JS, no WebView. Keep it that way.

---

## 2. Repository layout

```
lib/apex_dart.dart        Public barrel (export every public symbol here).
lib/src/
  utils/                  math, color, range/niceScale        (port + tests)
  options/                ApexOptions — the typed config model
  svg/                    Path/spline/text primitives over Canvas
  modules/                scales, layout, grid, legend, datalabels,
                          annotations, time_scale, ...
  charts/                 line, area, bar, pie/donut, scatter
  interaction/            hit-testing, tooltip, hover, zoom toolbar
reference/apexcharts-4.7.0-src/   ← THE SOURCE OF TRUTH (vendored, gitignored)
tool/                     Puppeteer reference renderer + JSON fixtures
test/
  flutter_test_config.dart  loads the Inter font for ALL tests (see §6)
  harness/                fixture loader, image diff, widget rasterizer
  golden/                 reference/*.png (ground truth) + golden tests
  utils|options|svg|interaction|modules/   unit tests
example/                  Flutter-web gallery demo app
```

`reference/` is not committed (19 MB). Re-clone deterministically:

```bash
git clone --branch v4.7.0 https://github.com/apexcharts/apexcharts.js \
  apex_dart/reference/apexcharts-4.7.0-src
# Pinned commit: 1e93a0d47b834111cf616fb6c78a263bbae7c1d8  (see NOTICE)
```

---

## 3. The transpilation workflow (per feature)

Follow this loop for every new chart type, option, or bug fix:

1. **Find the upstream code.** Search `reference/apexcharts-4.7.0-src/src/`
   for the behavior. Common locations:
   - `modules/settings/Options.js` + `modules/settings/Defaults.js` — the
     default option values (and **per-chart-type overrides**, e.g. `area()`).
   - `modules/Scales.js`, `modules/Range.js` — axis ranges & nice ticks.
   - `modules/TimeScale.js` + `utils/DateTime.js` — datetime axis ticks/labels.
   - `modules/Fill.js` + `modules/Graphics.js` (`drawGradient`) — fills.
   - `charts/Line.js`, `charts/Bar.js`, `charts/Pie.js` — series geometry.
   - `modules/ZoomPanSelection.js`, `modules/Toolbar.js`, `modules/Animations.js`
     — zoom/pan/toolbar and the path-morph animation.
   - `modules/tooltip/*`, `modules/Crosshairs.js` — tooltip & crosshair.

   ```bash
   rg -n "shadeIntensity|opacityFrom" reference/apexcharts-4.7.0-src/src
   ```

2. **Port it faithfully.** Map SVG/DOM → `Canvas`/`CustomPainter`. The *math*
   (scales, ticks, layout, path geometry) ports ~1:1; only the draw backend
   changes. Copy magic constants **verbatim** with a comment citing the source
   file. Document which upstream module each Dart file came from (every module
   already has this header — keep the convention).

3. **Verify against the real library with Puppeteer** (see §4). Do not trust
   your reading alone — render the genuine ApexCharts output and diff/inspect.

4. **Add tests**: a golden test for visuals, unit tests for math/parsing.

5. **`flutter analyze` clean + all tests green**, then commit.

6. **Export only via `lib/apex_dart.dart`.** New public types must be added to
   the barrel.

Read modules from `reference/` **on demand**, one at a time — never try to load
the whole 97-file tree into context.

---

## 4. Verifying with Puppeteer (the "I verified, didn't guess" step)

The ground truth for any pixel/number question is **the real ApexCharts v4.7.0
rendered headless in Chromium via Puppeteer**, not your interpretation of the
JS. There are two ways to use it.

### 4a. Golden references (the committed pipeline)

`tool/render_reference.mjs` renders every `tool/fixtures/*.json` with real
ApexCharts (the pinned `apexcharts@4.7.0` UMD bundle, inlined) to a fixed-size
PNG at DPR=1, animations disabled, into `test/golden/reference/<name>.png`.
Those PNGs are what the Flutter golden tests diff against.

```bash
cd tool && npm install          # first time only (puppeteer + apexcharts@4.7.0)
node render_reference.mjs        # regenerate all reference PNGs
```

To add a chart to the golden suite: drop a `tool/fixtures/<name>.json`
(`{ "name", "width", "height", "options": <ApexCharts options> }`), re-run the
renderer, then add a golden test that rasterizes the same options through
`ApexChart` and compares with `ImageDiff` (see `test/golden/*_golden_test.dart`).

### 4b. Ad-hoc inspection (when "why is the color/number off?")

When debugging a specific discrepancy, render the real chart and **read exact
values out of its DOM/pixels** instead of eyeballing. This is how the area
gradient bug was solved: a throwaway script dumped ApexCharts' actual SVG
`<stop>` colors and proved the fill fades to **white** (`rgba(255,255,255,.9)`),
not black — which pointed straight at `Defaults.area()` (`shade:'light'`).

Pattern for a throwaway inspector (delete it when done — do not commit):

```js
// tool/_inspect_something.mjs   (gitignored / temporary)
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

const __dirname = dirname(fileURLToPath(import.meta.url));
const apex = readFileSync(
  resolve(__dirname, 'node_modules/apexcharts/dist/apexcharts.min.js'), 'utf8');

const opts = { /* the ApexCharts options you are investigating */ };
opts.chart = { ...opts.chart, width: 800, height: 400,
               animations: { enabled: false } };

const html = `<!doctype html><html><head><meta charset="utf-8"/>
<style>*{margin:0;box-sizing:border-box}html,body{background:#fff}
#chart{width:800px;height:400px}</style><script>${apex}</script></head>
<body><div id="chart"></div><script>
window.__r=false;
new ApexCharts(document.querySelector('#chart'),${JSON.stringify(opts)})
  .render().then(()=>window.__r=true);
</script></body></html>`;

const browser = await puppeteer.launch({
  headless: 'new', args: ['--no-sandbox', '--force-device-scale-factor=1'] });
const page = await browser.newPage();
await page.setViewport({ width: 800, height: 400, deviceScaleFactor: 1 });
await page.setContent(html, { waitUntil: 'networkidle0' });
await page.waitForFunction('window.__r===true', { timeout: 10000 });
await new Promise((r) => setTimeout(r, 200)); // settle final paint

// Read whatever ground truth you need straight from the rendered DOM, e.g.
// gradient stops, computed styles, element geometry, tick label text:
const stops = await page.evaluate(() =>
  [...document.querySelectorAll('linearGradient stop')].map((s) => ({
    offset: s.getAttribute('offset'),
    color: s.getAttribute('stop-color') || s.style.stopColor,
    opacity: s.getAttribute('stop-opacity') ?? s.style.stopOpacity,
  })));
console.log(JSON.stringify(stops, null, 2));
// Or screenshot a region / sample pixels for color questions.
await browser.close();
```

```bash
cd tool && node _inspect_something.mjs   # then delete the file
```

Useful selectors when inspecting ApexCharts' SVG: `linearGradient stop`,
`.apexcharts-xaxis-label`, `.apexcharts-yaxis-label`, `.apexcharts-series path`,
`.apexcharts-xcrosshairs`, `.apexcharts-tooltip`.

You can also visually confirm a Flutter render by writing a temporary export
test that rasterizes `ApexChart` to a PNG via `test/harness/render_widget.dart`
(`rasterizeWidget`) and saving it under `test/golden/failures/` — then read the
PNG back to compare against the Puppeteer output. Delete temp tests afterward.

---

## 5. Commands

```bash
cd apex_dart

# Analyze (must be clean before committing)
~/fvm/versions/3.38.7/bin/flutter analyze lib test

# Tests — whole suite, or a subset (faster while iterating)
~/fvm/versions/3.38.7/bin/flutter test
~/fvm/versions/3.38.7/bin/flutter test test/golden test/interaction test/options

# Regenerate goldens after an INTENTIONAL visual change (review the diff!)
~/fvm/versions/3.38.7/bin/flutter test --update-goldens

# Reference PNGs from the real ApexCharts (Puppeteer)
cd tool && npm install && node render_reference.mjs

# Build + serve the example gallery (web)
cd example && ~/fvm/versions/3.38.7/bin/flutter build web --release
pkill -f "http.server 8099"; cd build/web && (python3 -m http.server 8099 &)
# → http://localhost:8099
```

---

## 6. Fonts & rendering parity (don't skip this)

ApexCharts' web default font is Helvetica/Arial. Tests load **Inter** as a
metric proxy so text rasterizes consistently:

- `test/flutter_test_config.dart` registers `Inter` via `FontLoader` for
  **all** tests. Without it Flutter uses "Ahem" (every glyph a solid box),
  which destroys any diff.
- Pass `fontFamily: 'Inter'` through `ApexOptions.copyWith(...)` in tests and
  the example so labels match the references.
- `dart:ui` image codecs need `tester.runAsync()` (the fake-async test zone
  doesn't pump them) — see `render_widget.dart`.
- MaterialIcons are **not** loaded in the test harness, so toolbar icons show
  as empty boxes in test PNGs. They render correctly on web — don't "fix" this.

Parity is **perceptual, not bit-exact**: SVG (Chromium) vs Skia anti-aliasing
will always differ slightly. Golden tests assert a mismatched-pixel *fraction*
under a tolerance and emit a 3-up diff (`reference | candidate | mask`) into
`test/golden/failures/` on failure. Tune tolerances per chart; flag if a change
makes one worse.

---

## 7. Conventions

- **Cite the source.** Each ported file carries a header comment naming the
  ApexCharts module it came from. Magic constants are copied verbatim with a
  comment pointing at the upstream file. Keep doing this.
- **No new runtime deps.** Pure `CustomPainter`. If you reach for a package,
  reconsider.
- **Dart style:** `flutter_lints` + strict-casts (see `analysis_options.yaml`).
  Classes PascalCase, files snake_case, private members `_prefixed`.
- **Commits:** `feat(apex_dart): ...` / `fix(apex_dart): ...`, describing *why*
  and naming the upstream module the behavior was ported from. Don't commit
  `reference/`, build output, `node_modules`, font copies, or temp inspector
  scripts. Don't push unless explicitly asked.
- **Licensing:** v4.7.0 (MIT) source **only**. Never copy from v5+ (non-MIT).

---

## 8. Definition of done (per change)

- [ ] Behavior traced to a specific line in `reference/apexcharts-4.7.0-src/`.
- [ ] Verified against real ApexCharts via Puppeteer (golden and/or inspector).
- [ ] Unit tests for new math/parsing; golden test for new visuals.
- [ ] `flutter analyze lib test` clean; full `flutter test` green.
- [ ] New public symbols exported from `lib/apex_dart.dart`.
- [ ] Temp scripts/PNGs removed; nothing gitignored got staged.
