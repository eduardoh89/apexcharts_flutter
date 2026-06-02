// Renders every fixture in ./fixtures/*.json with the real ApexCharts v4.7.0
// (MIT) and writes a fixed-size PNG to ../test/golden/reference/<name>.png.
//
// These PNGs are the ground truth the Flutter golden tests diff against.
//
// Usage:
//   cd tool && npm install && node render_reference.mjs
//
// Requirements: node >= 18, puppeteer (Chromium), apexcharts@4.7.0 (both are
// declared in tool/package.json).

import { readFileSync, readdirSync, mkdirSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import puppeteer from 'puppeteer';

const __dirname = dirname(fileURLToPath(import.meta.url));
const FIXTURES_DIR = join(__dirname, 'fixtures');
const OUT_DIR = resolve(__dirname, '..', 'test', 'golden', 'reference');

// Locate the installed ApexCharts UMD bundle so we inline it (offline, pinned).
const APEX_JS = resolve(
  __dirname,
  'node_modules',
  'apexcharts',
  'dist',
  'apexcharts.min.js'
);

// Device pixel ratio for the screenshots. Flutter goldens render at logical
// pixels; we keep DPR = 1 on both sides so geometry lines up 1:1.
const DPR = 1;

function loadFixtures() {
  return readdirSync(FIXTURES_DIR)
    .filter((f) => f.endsWith('.json'))
    .map((f) => JSON.parse(readFileSync(join(FIXTURES_DIR, f), 'utf8')));
}

function buildHtml(apexSource, fixture) {
  // Force chart size + disable animations so the screenshot is deterministic.
  const opts = structuredClone(fixture.options);
  opts.chart = opts.chart || {};
  opts.chart.width = fixture.width;
  opts.chart.height = fixture.height;
  opts.chart.animations = { enabled: false };
  opts.chart.redrawOnParentResize = false;

  return `<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <style>
      * { margin: 0; padding: 0; box-sizing: border-box; }
      html, body { background: #ffffff; }
      #chart {
        width: ${fixture.width}px;
        height: ${fixture.height}px;
      }
    </style>
    <script>${apexSource}</script>
  </head>
  <body>
    <div id="chart"></div>
    <script>
      const options = ${JSON.stringify(opts)};
      window.__rendered = false;
      const chart = new ApexCharts(document.querySelector('#chart'), options);
      chart.render().then(() => { window.__rendered = true; });
    </script>
  </body>
</html>`;
}

async function main() {
  if (!existsSync(APEX_JS)) {
    console.error(
      `ApexCharts bundle not found at ${APEX_JS}.\n` +
        `Run "npm install" inside the tool/ directory first.`
    );
    process.exit(1);
  }
  mkdirSync(OUT_DIR, { recursive: true });

  const apexSource = readFileSync(APEX_JS, 'utf8');
  const fixtures = loadFixtures();

  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--force-device-scale-factor=1'],
  });

  try {
    for (const fixture of fixtures) {
      const page = await browser.newPage();
      await page.setViewport({
        width: fixture.width,
        height: fixture.height,
        deviceScaleFactor: DPR,
      });
      await page.setContent(buildHtml(apexSource, fixture), {
        waitUntil: 'networkidle0',
      });
      await page.waitForFunction('window.__rendered === true', {
        timeout: 10000,
      });
      // Small settle delay for final paint.
      await new Promise((r) => setTimeout(r, 150));

      const el = await page.$('#chart');
      const outPath = join(OUT_DIR, `${fixture.name}.png`);
      await el.screenshot({ path: outPath });
      console.log(`✓ ${fixture.name} -> ${outPath}`);
      await page.close();
    }
  } finally {
    await browser.close();
  }

  console.log(`\nDone. ${fixtures.length} reference PNG(s) in ${OUT_DIR}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
