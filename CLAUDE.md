# CLAUDE.md

pitwall is a project of the [Data Engineering Lab](https://github.com/TomasRipsky/data-engineering-lab).
The lab is the base: its `CLAUDE.md` (hard rules, tutoring, Definition of Done), `lab/conventions.md`,
`lab/security-and-cost.md`, skills, hooks and agent all live there and apply here.

**Start Claude Code sessions in the lab checkout and add this repository as a working directory.**
If this session started here instead, read the lab's `CLAUDE.md` before changing anything.

What lives in this repository:

- `README.md` — what pitwall does, how to run it, cost and teardown.
- `docs/guide.md` — how it works inside (being written: issue #1). `docs/decisions/` — its ADRs. `docs/design/` — specs and plans (records).
- `site/` — the public dashboard (`site/README.md`). `infra/gcp/` — Terraform; state is local, never committed.

Git here follows the lab's flow: issue → `<type>/<issue#>-<slug>` from `dev` → PR into `dev` → squash;
releases are `dev → main` merge commits and only with Tomas's OK. A push to `main` runs the
production pipeline and republishes the site.
