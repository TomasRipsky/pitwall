# pitwall site

The public dashboard: https://tomasripsky.github.io/pitwall/ — Observable Framework on GitHub Pages
([ADR 0007](../docs/decisions/0007-observable-framework-for-the-dashboard.md)).

## How it is built

1. **Data is exported, never queried from the site.** `pitwall site-export --out site/src/data`
   (`make site-data`) writes one Parquet file per chart into `src/data/` (git-ignored) before the
   build. In production it runs as the read-only dashboard account and exports only data we are
   happy to publish.
2. **Two pages.** `src/index.md` is the story: hero, the answers, the analysis sections, a case
   file, the pipeline, decisions, quality, limits. `src/bi.md` is the self-service page: filters,
   KPIs, tables with CSV download. Both compute their figures in the browser from the exported
   rows. Framework's own chrome (sidebar, pager, header, footer) is off in `observablehq.config.js`;
   the old page URLs are kept as redirect pages.
3. **Look.** `src/components/lab.css` and `lab.js` are the skeleton every Data Engineering Lab
   site shares (sticky bar, hero, bands, panels, tiles, KPIs, filter bar; `rows`, `fmt`,
   `downloadButton`), driven by `--lab-*` variables. `src/pitwall.css` sets those variables and
   adds what is only Formula 1 — start lights, kerbs, pit boards — with its encodings, charts and
   illustrations in `src/components/f1.js`, `charts.js` and `art.js`. Illustrations are our own: never
   trademarked logos or photos. Charts follow the `dataviz` skill (validated palettes, one axis,
   legends, tooltips).
4. **Every section** says what the reader is looking at in plain language (`.sub`) before the
   chart and states its limits after it (`.footnote`). No F1 knowledge is assumed. Charts are
   functions of the panel width, drawn through `resize()`.
   In htl templates leave a space before `/>` after an interpolated attribute (`d=${path} />`):
   without it the slash becomes part of the value.
5. **Browser-friendly data**: no 64-bit integers (they arrive as `BigInt`) and no timestamps
   (format dates as strings); show medians for long-tailed durations.

## Build and publish

```bash
make site-preview   # from the repository root: export dev data, live reload on http://127.0.0.1:3000
make site           # export + build into site/dist
```

`pitwall-pipeline` exports from prod, builds and deploys to GitHub Pages after every successful
production run; `pitwall-ci` builds the site with dev data on every pull request. What is exported
is decided in dbt (`transform/models/marts/reports/`), not here.
