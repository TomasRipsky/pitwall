# pitwall site

The public dashboard: https://tomasripsky.github.io/pitwall/ — Observable Framework on GitHub Pages
([ADR 0007](../docs/decisions/0007-observable-framework-for-the-dashboard.md)).

## How it is built

1. **Data is exported, never queried from the site.** `pitwall site-export --out site/src/data`
   (`make site-data`) writes one Parquet file per chart into `src/data/` (git-ignored) before the
   build. In production it runs as the read-only dashboard account and exports only data we are
   happy to publish.
2. **Pages** are the Markdown files in `src/`; the sidebar is `observablehq.config.js`.
3. **Look.** `src/components/lab.css` and `lab.js` are the structure every Data Engineering Lab
   site shares (cards, big numbers, callouts, `rows`, `fmt`). `src/pitwall.css` is pitwall's own
   theme on top — the dark pit-wall screen, tyre and team colours — with its encodings and
   illustrations in `src/components/f1.js` and `art.js`. Illustrations are our own: never
   trademarked logos or photos. Charts follow the `dataviz` skill (validated palettes, one axis,
   legends, tooltips).
4. **Page skeleton** (every page):
   - H1 phrased as the question the page answers;
   - `<div class="tip" label="What am I looking at?">` explaining the page in plain language;
   - the charts;
   - `<div class="note">` with the limitations.
5. **Browser-friendly data**: no 64-bit integers (they arrive as `BigInt`) and no timestamps
   (format dates as strings); show medians for long-tailed durations.

## Build and publish

```bash
make site-preview   # from the repository root: export dev data, live reload on http://127.0.0.1:3000
make site           # export + build into site/dist
```

`pitwall-pipeline` exports from prod, builds and deploys to GitHub Pages after every successful
production run; `pitwall-ci` builds the site with dev data on every pull request.
