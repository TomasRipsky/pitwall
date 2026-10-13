# Changelog

All notable changes to pitwall are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning: [SemVer](https://semver.org/).

## [Unreleased]

### Fixed
- Safety Car periods no longer run to the end of the race when a red flag follows them in 2026 data:
  the source stopped sending red flags as flags and only reports `SESSION ABORTED`, which the model
  now reads as a red flag (Monte Carlo, Zandvoort and Monza 2026 were affected — Monza showed 51 of
  53 laps under the Safety Car). Virtual Safety Car periods announced as `VSC DEPLOYED` / `VSC ENDING`
  (10 sessions) are recognised. A new warning test lists any Safety Car message the models do not know.

## [1.0.0] - 2026-10-13

The first release of pitwall as its own repository. Nothing changes in what the pipeline does or shows.

### Changed
- pitwall lives in its own repository, extracted with its history from the
  [Data Engineering Lab](https://github.com/TomasRipsky/data-engineering-lab) monorepo (lab ADR 0007).
  Commits made before the move name lab issues and pull requests as `data-engineering-lab#N`.
- The dashboard is this repository's own GitHub Pages site: https://tomasripsky.github.io/pitwall/
  (the lab's site redirects the old address). Pages sit at the site root and `make site-data` writes to `site/src/data`.
- CI runs on every pull request (no path filters), and Workload Identity Federation trusts this
  repository instead of the lab.

## Before this repository

pitwall was released as part of the lab (tags `v0.3.0`–`v1.0.0` there):

- **Lab 1.0.0 and after (2026-09-30 → 2026-10-01)** — specs and plans moved to `docs/design/`;
  a negative or non-finite `Retry-After` falls back to exponential backoff; the contract check warns
  when an optional field is absent from every record.
- **Lab 0.4.0 (2026-09-30)** — public race-strategy site: stint timelines with Safety Car shading,
  fuel-corrected tyre wear, undercut success; rebuilt by the pipeline from prod through a read-only
  account (ADR 0007).
- **Lab 0.3.0 (2026-09-30)** — OpenF1 extractor writing contract-checked Parquet to a raw lake;
  GCP environments with Terraform, Workload Identity Federation, query quota and budget;
  `pitwall load`; the dbt project (staging → intermediate → marts) with unit-tested racing rules and
  data-quality rules; CI and the scheduled production pipeline.
