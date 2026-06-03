# Contributing to apexcharts_flutter

Thanks for your interest! This package is a **native port of ApexCharts
v4.7.0**, so it has one guiding rule.

## The one rule

> **This is a transpilation, not a reinvention.** Never guess behavior — read
> the original ApexCharts v4.7.0 source, port it faithfully, then verify
> against the real library.

Every visual/numeric decision should be traceable to a specific file/line in
the upstream source. If you can't point at the upstream code that justifies a
constant, a formula, or a default, it's a guess — go read the source first.

When you fix or add something, name the upstream module it came from in the
commit message (e.g. `Fill.js` / `Defaults.area()`).

> **License boundary:** only ApexCharts **v4.7.0** (MIT) source may be used as
> a reference. Never copy from v5+ (non-MIT).

## Getting the upstream reference

The pristine upstream tree is **not** committed (it's ~19 MB and gitignored).
Re-clone it deterministically:

```bash
git clone --branch v4.7.0 https://github.com/apexcharts/apexcharts.js \
  reference/apexcharts-4.7.0-src
# Pinned commit: 1e93a0d47b834111cf616fb6c78a263bbae7c1d8  (see NOTICE)
```

## Workflow

1. Find the upstream code in `reference/apexcharts-4.7.0-src/src/`.
2. Port it to `CustomPainter`/`Canvas`. The math ports ~1:1; only the draw
   backend changes. Copy magic constants verbatim with a comment citing the
   source file.
3. Verify against real ApexCharts (see below).
4. Add tests: a golden test for visuals, unit tests for math/parsing.
5. `flutter analyze` clean + `flutter test` green.
6. Export new public types from `lib/apexcharts_flutter.dart`.

## Verifying against real ApexCharts (Puppeteer)

The ground truth for any pixel/number question is the real ApexCharts v4.7.0
rendered headless in Chromium. The reference PNGs the golden tests diff against
are produced by `tool/render_reference.mjs` and are **not committed** (they're
regenerated locally):

```bash
cd tool && npm install        # first time (puppeteer + apexcharts@4.7.0)
node render_reference.mjs      # regenerate reference PNGs
```

Golden tests **self-skip** when the reference PNGs are absent, so CI stays green
without them. Run them locally after generating the references.

## Commands

```bash
flutter pub get
dart format .
flutter analyze
flutter test
flutter test --update-goldens   # after an INTENTIONAL visual change (review the diff!)
```

See [`AGENTS.md`](AGENTS.md) for the full working guide.

## Style

- `flutter_lints` + strict-casts (see `analysis_options.yaml`).
- Classes PascalCase, files snake_case, private members `_prefixed`.
- Each ported file carries a header comment naming the ApexCharts module it
  came from. Keep that convention.
- No new runtime dependencies — pure `CustomPainter`.
