"""Data for the site: copy the report models to browser-friendly Parquet.

The site never queries BigQuery itself: `pitwall site-export` writes these files into
`site/src/data/` before the site is built (ADR 0007). What each file holds is decided in dbt
(`transform/models/marts/reports/rpt_*.sql`: one grain each, documented and tested) — this module
only copies, so a number on the site can always be traced to rows of a tested table (ADR 0008).
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

import pyarrow as pa
import pyarrow.parquet as pq

# One file per report model: `rpt_races` becomes `races.parquet`.
REPORTS = (
    "races",
    "driver_races",
    "laps",
    "stints",
    "pit_stops",
    "tyre_wear",
    "undercuts",
    "neutralisations",
)

QUERIES: dict[str, str] = {
    name: f"select * from `{{project}}.marts.rpt_{name}`" for name in REPORTS
}

# The page is unusable without these two: an empty one must stop the run.
REQUIRED = ("races", "driver_races")


def query(sql: str, *, project: str | None = None, client: Any = None) -> pa.Table:
    """Run `sql` (with `{project}` filled in) and return the result as an Arrow table."""
    project = project or os.environ["PITWALL_BQ_PROJECT"]
    if client is None:
        from google.cloud import bigquery

        client = bigquery.Client(project=project)
    return client.query(sql.format(project=project)).to_arrow()


def browser_friendly(table: pa.Table) -> pa.Table:
    """Narrow 64-bit integers to 32-bit: Arrow JS reads int64 as BigInt, which charts can't plot.

    The cast is safe: a value that doesn't fit raises instead of wrapping around.
    """
    fields = [
        pa.field(field.name, pa.int32()) if pa.types.is_int64(field.type) else field
        for field in table.schema
    ]
    return table.cast(pa.schema(fields))


def export(out_dir: Path, *, project: str | None = None, client: Any = None) -> dict[str, int]:
    """Write one Parquet file per query into `out_dir`; return the rows written per file."""
    project = project or os.environ["PITWALL_BQ_PROJECT"]
    if client is None:
        from google.cloud import bigquery

        client = bigquery.Client(project=project)
    tables = {
        name: browser_friendly(query(sql, project=project, client=client))
        for name, sql in QUERIES.items()
    }
    # Never publish an empty site: failing here keeps the last good version online.
    empty = [name for name in REQUIRED if tables[name].num_rows == 0]
    if empty:
        raise ValueError(f"refusing to export an empty site: no rows in {', '.join(empty)}")
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, table in tables.items():
        pq.write_table(table, out_dir / f"{name}.parquet", compression="snappy")
    return {name: table.num_rows for name, table in tables.items()}
