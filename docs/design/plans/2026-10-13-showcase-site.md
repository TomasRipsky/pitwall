# Showcase site — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace pitwall's four-page dashboard with a one-page story and a BI page in the style of MarineFlow and CityPulse, fed by tested dbt report models.

**Architecture:** dbt `rpt_*` tables in `marts` → `pitwall site-export` copies them to Parquet → Observable Framework builds `index.md` (story, plain JS over Arrow) and `bi.md` (DuckDB-WASM). Shared skeleton in `components/lab.css`, Formula 1 theme in `pitwall.css`.

**Tech Stack:** dbt (BigQuery), Python + pyarrow, Observable Framework 1.13.4, Observable Plot, DuckDB-WASM.

**Spec:** `docs/design/specs/2026-10-13-showcase-site-design.md`

## Global Constraints

- Branch `feat/13-showcase-site`; PR into `dev` with `Closes #13`; no release in this plan.
- No new dependency, action or cloud resource; cost stays €0.
- SQL: lowercase, CTEs, one model = one grain, stated in a header comment and in the YAML.
- Browser data: no timestamps (dates as `YYYY-MM-DD` strings), no 64-bit integers after export.
- Every figure shown is computed from exported rows; no number or race story is typed by hand.
- No official logos, photos or team marks. Colour never carries meaning alone.
- Site copy in English, written for a reader who does not follow F1.

## Review Focus

1. **A report model with the wrong grain** (a join that fans out) → `unique` test on each model's key columns; row counts compared with the source fact in the PR.
2. **Sprints polluting race statistics** (no mandatory stop, no published grid) → headline numbers filter `session_name = 'Race'` where the claim is about races; a pytest on the export checks the column exists.
3. **Missing data drawn as zero** (2023 stops without timing, null positions) → nulls stay null in the models; charts filter `!= null` explicitly.
4. **A filter combination with no rows on the BI page** → every block renders an empty state instead of throwing; checked with a 2023 + Sprint + one team selection.
5. **The case file picking a broken record** → it requires a published grid and a classified finish; the chosen race is printed in the PR for a sanity check.
6. **Old URLs** → after the build, the four redirect pages exist and contain their target.

## Tasks

### Task 1: Report models
- [ ] `transform/models/marts/reports/rpt_{races,driver_races,laps,stints,pit_stops,tyre_wear,undercuts,neutralisations}.sql` + `_reports.yml` (grain, column docs, tests: unique key, not-null keys, accepted values for `session_name`, `compound`, `neutralisation`, `pit_timing`).
- [ ] `make transform ENV=dev` green; row counts: `rpt_laps` = `fct_laps`, `rpt_stints` = `fct_stints`, `rpt_pit_stops` = `fct_pit_stops`, `rpt_undercuts` = `fct_undercut_attempts`, `rpt_races` = `dim_sessions`, `rpt_driver_races` = `fct_session_results`.

### Task 2: Export
- [ ] Tests first (`tests/test_site_data.py`): one query per report model, each `select * from marts.rpt_<name>`; file named without the prefix; empty-site guard on `races` and `driver_races`; int64 narrowing kept.
- [ ] `src/pitwall/site_data.py`: `REPORTS` tuple + generated queries; `FUEL_S_PER_LAP` moves into the dbt model as a var.
- [ ] `make site-data ENV=dev`; record file sizes.

### Task 3: Skeleton and theme
- [ ] `components/lab.css` (structure, `--lab-*` variables), `pitwall.css` (tokens, start lights, kerb, pit boards), `observablehq.config.js` (no sidebar/pager/toc, empty header/footer, favicon, theme colour).
- [ ] `components/art.js`: `startLights()`, `logo()`, circuit-lap pipeline; `components/f1.js`: team-colour helpers; `components/charts.js`: the chart functions used by both pages.

### Task 4: Story page
- [ ] `site/src/index.md`, sections 1–13 of the spec; redirect pages for the four old URLs.
- [ ] Build; open at 1280 px and 375 px; no console errors; every section renders with dev data.

### Task 5: BI page
- [ ] `site/src/bi.md`: filter bar, KPIs, six sections, CSV downloads, empty states.
- [ ] Check with all filters default, and with 2023 + Sprint + one team.

### Task 6: Docs and ship
- [ ] `README.md` (dashboard section, data model table gains the report layer), `site/README.md`, `CHANGELOG.md`, ADR `0008-showcase-site-story-and-bi.md`.
- [ ] `make lint`, `make test`, `make transform ENV=dev`, `make site ENV=dev`; `ship` (PR, CI, `pr-reviewer`, squash).

### Task 7: The lab standard (lab PR)
- [ ] `template/site/`: skeleton `lab.css`, neutral theme, story and BI page stubs; `lab/conventions.md` section; lab ADR 0008; hub stubs point at the sections.
