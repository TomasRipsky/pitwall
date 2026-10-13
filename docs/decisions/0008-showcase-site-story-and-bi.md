# 0008 — The site is a story page and a BI page, fed by dbt report models

- **Status:** Accepted
- **Date:** 2026-10-13

## Context
pitwall's first site (ADR 0007) was four dashboard pages with a sidebar: correct, but it read as a
tool, not as a project. Tomas asked for the style of the lab's two other showcases — MarineFlow and
CityPulse — a personality that says Formula 1, as much as the data allows, and a BI-style section;
and for that style to become the standard of every lab project (lab ADR 0008).

Two things had grown in the wrong place. The SQL behind the charts lived in a Python dictionary
(`site_data.py`), untested by dbt and invisible to its docs. And the marts held far more than the
site showed: a position for 99.7 % of 103 549 laps, results with grid and finish, 25 circuits.

## Decision
1. **Report models in dbt.** Eight `rpt_*` tables (`transform/models/marts/reports/`) hold exactly
   what the site reads: one grain each, documented column by column, tested like any other model,
   browser-friendly (dates as text, rounded numbers). `pitwall site-export` only copies them.
2. **One story page.** `index.md` follows the lab's showcase skeleton: hero → the answers → the
   analysis sections → a case file picked by a query → the pipeline → decisions → quality → limits →
   run it. Every figure is computed in the browser from the exported rows.
3. **A BI page.** `bi.md`: filters (season, session, circuit, team), KPIs, tables and charts for
   drivers, teams, circuits, tyres, the pit-stop log and data quality by race, with CSV downloads.
4. **Structure and theme are separate files.** `components/lab.css` is the skeleton shared by every
   lab site; `pitwall.css` sets its variables and adds what is only Formula 1.

## Alternatives considered
- **Keep the SQL in Python** — no new models, but the numbers people see stay outside dbt's tests,
  docs and lineage. This was the weakest part of the first site.
- **DuckDB in the browser for the BI page**, as CityPulse does — right for its 44 M trips, where
  the page must aggregate large Parquet files. pitwall's tables are 100–5 000 rows (laps: 100 000,
  read one race at a time): filtering in memory gives the same page without shipping a query
  engine. Revisit if telemetry is ever added.
- **Hand-written HTML and JavaScript**, as MarineFlow — full control, but pitwall already builds
  with Observable Framework and Plot (ADR 0007), which give responsive charts and inputs for free.
- **Keep the four pages and restyle them** — less work, but the reader would still have to
  assemble the story from a menu.
- **A new `reports` dataset** — cleaner separation, but it needs Terraform and IAM changes in two
  projects for no reader-visible gain; the models live in `marts`, which the dashboard account
  already reads.

## Consequences
- A number on the site can be traced to rows of a tested table; changing what the site shows is a
  dbt change with a reviewable diff.
- The old page URLs (`race-strategy`, `tyre-wear`, `undercut`, `about`) remain as redirects to the
  matching sections.
- The page loads about 1 MB of Parquet. The largest file (`laps`, ~840 KB) is kept as an Arrow
  table and read one race at a time.
- The case file is whatever race the data says was won from furthest back: it can change after any
  Monday run, and it exposes data problems early — building it is how issue #14 was found.
- CI's site build exports from the dev marts, so new report models must be built in dev before a
  pull request that needs them can pass (a known limit; see the README).
