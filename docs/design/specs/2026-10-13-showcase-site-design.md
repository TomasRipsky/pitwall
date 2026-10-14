# Showcase site — design

- **Date:** 2026-10-13
- **Issue:** #13

## 1. Intent

Tomas (2026-10-13): present pitwall with a dashboard "following the standard set by MarineFlow",
with the technology used for MarineFlow and CityPulse, a personality that represents Formula 1,
pleasant to look at, as complete as our data allows, and — if possible — a BI-style section like
CityPulse's. This style becomes the standard for every lab project from now on.

**Success:** a visitor who knows nothing about F1 or data engineering understands, on one page,
what pitwall answers, sees it in the data, and can see how it is built; a curious one can slice the
data on a second page; the next project starts from the same skeleton.

**Decisions taken by Claude (Tomas was away; revisable):**

| Question | Decision | Why |
|---|---|---|
| Technology | Observable Framework, as CityPulse | MarineFlow's site is hand-written HTML/JS; CityPulse reproduced its style on Framework. pitwall already uses Framework and the BI page needs its DuckDB-in-the-browser support. |
| Shape | One long story page + `/bi` | That is what both reference sites are; the four old pages become sections. |
| Where report logic lives | dbt `rpt_*` models | Tested SQL with stated grains instead of queries inside a Python string; the export becomes a copy. CityPulse did the same. |
| Release | Build and merge to `dev`, stop before `main` | A release publishes the site; it needs Tomas's explicit OK. |

## 2. Verified facts (2026-10-13)

- MarineFlow's site: `index.html` + `assets/{app.js,style.css,data.js}`, no framework — source: `ls ~/…/MarineFlow/site`. CityPulse's: Observable Framework 1.13.4, one long page (`sidebar/pager/toc` off, empty `header`/`footer`) + `bi.md` with `sql:` front matter over Parquet — source: its `observablehq.config.js`, `src/bi.md`.
- Both share one skeleton: sticky top bar (brand → top, section anchors, GitHub) → illustrated hero with live stats → the answers as domain-themed tiles → analysis sections alternating `band`/`wrap` → a case file → the pipeline drawn in the domain's language → decisions → quality → limits → run it → footer.
- Framework front matter can override `head`, `header`, `footer`, `sidebar`, `toc`, `style` per page, and `sql:` registers Parquet files as DuckDB tables — source: Framework docs (`markdown.md`, `config.md`) via Context7.
- Dev marts (2026-10-13): 108 sessions (85 Races, 23 Sprints, 2023–2026), 103 549 laps (99.7 % with a position, 99.2 % with sector times, 85.8 % clean), 5 462 stints, 3 289 pit stops (3 066 with pit-lane time; stationary time only from 2024: 1 038), 697 undercut attempts, 2 196 results, 29 drivers, 15 team names, 25 circuits — source: `bq query` on `pitwall-tr-dev.marts`.
- The dashboard service account reads the `marts` dataset only — source: `infra/gcp/iam.tf`. Report models therefore stay in `marts`: no infrastructure change, cost unchanged (€0).
- CI's `site-data` job exports from the **dev marts**, not from the PR's own datasets — source: `pitwall-ci.yml`. New models must exist in dev before the PR's site build can pass.

## 3. Data: report models

`transform/models/marts/reports/`, materialised as tables in `marts`, each documented with its grain
and tested (unique key, not-null keys, accepted values). Dates are strings and numbers are rounded:
these tables are read by a browser.

| Model | Grain | Feeds |
|---|---|---|
| `rpt_races` | one Race or Sprint | selectors, hero stats, circuits, data quality (laps timed, pit-timing source, grid published) |
| `rpt_driver_races` | one driver in one session | results, grid vs finish, championship tables, pace gap, the case file |
| `rpt_laps` | one lap of one driver | lap chart (position by lap), pace |
| `rpt_stints` | one set of tyres | strategy timeline, stint lengths, wear by stint |
| `rpt_pit_stops` | one pit stop | pit loss by circuit, crews, stops under neutralisation, the log |
| `rpt_tyre_wear` | circuit (or all) × compound × tyre age | wear curves, raw and fuel-corrected |
| `rpt_undercuts` | one undercut attempt | success rates |
| `rpt_neutralisations` | one neutralised lap of a session | Safety Car / red-flag shading |

`pitwall site-export` writes one Parquet file per model (`races.parquet`, …) and still refuses to
publish an empty site. Aggregations for the pages are done in the browser from these grains, so a
number on the site can always be traced to rows.

## 4. The story page (`site/src/index.md`)

Dark pit-wall look (existing palette and Titillium Web), original illustrations only.

| # | Section | Content |
|---|---|---|
| — | Top bar | tyre logo → top; anchors; **BI**; GitHub |
| 1 | Hero | five start lights going out, the car over a kerb; H1 as the question; stats: races, laps, pit stops, latest Grand Prix |
| 2 | The answers | six **pit boards** (what a team shows its driver): the cost of a stop, one stop or two, wear per lap by tyre, undercut success, stops taken under the Safety Car, wins from pole |
| 3 | Race explorer | pick a season and a race: strategy timeline (stints, stops, neutralisations) and **lap chart** (position by lap, team colours), result table |
| 4 | Tyres | wear curve by circuit (fuel correction toggle), how long each compound lasts, what each circuit runs |
| 5 | Pit stops | time lost in the pit lane by circuit, fastest crews (stationary time), stops under green vs neutralised |
| 6 | The undercut | how it works in three steps; success by lap gap, season and team |
| 7 | Does the grid decide? | grid × finish heat map; where winners start; street vs permanent circuits |
| 8 | Case file | the win from furthest back in the data, told lap by lap (computed at build time, never hard-coded) |
| 9 | The pipeline | one lap of the data: each stage a sector; stack table |
| 10 | Decisions | one box per ADR |
| 11 | Quality | tests and data-quality rules, what fails vs warns |
| 12 | Limits | stated plainly |
| 13 | Run it | commands; links |

Every chart keeps the page rule of the lab: a plain-language "what am I looking at" before it and
its limits after it. No F1 knowledge is assumed: terms are explained where they first appear.

## 5. The BI page (`site/src/bi.md`)

The same Parquet files, filtered in the browser. *(Revised while building: the first draft said
DuckDB-WASM, as CityPulse uses; pitwall's tables are small enough to filter in memory, which gives
the same page without shipping a query engine — ADR 0008.)* A sticky filter bar — **season, session
(Race/Sprint), circuit, team** — drives everything; where a number cannot follow a filter it says so.

KPIs (races, laps, pit stops, median pit-lane time under green, median stationary time, undercut
success) → **Drivers** (races, wins, podiums, points, average grid and finish, places gained, pace
gap) → **Teams** (points by season, pit crew times) → **Circuits** (pit loss, stops per driver,
neutralised laps, pole-to-win) → **Tyres** (stints and wear by compound) → **Pit-stop log** →
**Data quality by race** (laps timed, pit timing official or inferred, grid published). Tables
download as CSV.

## 6. Old URLs

`race-strategy`, `tyre-wear`, `undercut` and `about` stay as pages whose only content is a
`head` redirect to the matching section (`./#race`, `./#tyres`, `./#undercut`, `./#pipeline`) and a
visible link. The lab hub's stubs keep working through them and are pointed straight at the
sections in the lab change.

## 7. The standard

Structure and colour are separated so the next project inherits the first and brings the second:
`components/lab.css` holds the skeleton (top bar, hero frame, bands, panels, tiles, KPIs, filter
bar, case, check lists, run block, footer) driven by `--lab-*` variables; `pitwall.css` sets the
variables and adds what is only Formula 1 (start lights, kerbs, pit boards). After this ships, the
lab gets the skeleton in `template/site/` (story page and BI page stubs), the section list in its
conventions, and an ADR recording the standard.

## 8. Risks

| Risk | Guard |
|---|---|
| A number on the site disagrees with the marts | Report models are tested in dbt; headline numbers are computed from exported rows and spot-checked against `bq` in the PR. |
| The page is heavy (100 k laps) | `rpt_laps` carries only what the charts need; measured file sizes are reported in the PR; charts for a race filter in memory. |
| F1 claims from memory instead of data | Every figure and the case file are computed from the export; prose states only what the data shows. |
| Unreadable on a phone, or without colour vision | Checked at 375 px; compounds and teams always carry a letter or a name besides colour; `dataviz` palette rules. |
| Old links break | Redirect pages for the four old URLs, checked after the build. |
| Trademarks | No logos or photos; the disclaimer stays in the footer. |

## 9. Out of scope

Telemetry (car data, positions on track), qualifying and practice sessions, live timing, predictions.
The tutoring walkthrough of this change goes into `docs/guide.md` with issue #1.
