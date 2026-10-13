# Changelog

All notable changes to pitwall are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning: [SemVer](https://semver.org/).

## [Unreleased]

### Changed
- pitwall lives in its own repository, extracted with its history from the
  [Data Engineering Lab](https://github.com/TomasRipsky/data-engineering-lab) monorepo (lab ADR 0007).
  Commits made before the move name lab issues and pull requests as `data-engineering-lab#N`.
- The dashboard is this repository's own GitHub Pages site: https://tomasripsky.github.io/pitwall/
  (the old address redirects). Pages sit at the site root and `make site-data` writes to `site/src/data`.
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
