import re
from pathlib import Path

import pyarrow as pa
import pyarrow.parquet as pq
import pytest

from pitwall.site_data import QUERIES, browser_friendly, export, query

TRANSFORM = Path(__file__).parent.parent / "transform"


class FakeClient:
    def __init__(self, table):
        self.table = table
        self.sql = []

    def query(self, sql):
        self.sql.append(sql)
        return self

    def to_arrow(self):
        return self.table


def test_query_fills_in_the_project():
    client = FakeClient(pa.table({"a": [1]}))
    query(
        "select 1 from `{project}.marts.dim_sessions`",
        project="pitwall-tr-dev",
        client=client,
    )
    assert client.sql == ["select 1 from `pitwall-tr-dev.marts.dim_sessions`"]


def test_browser_friendly_narrows_64_bit_integers():
    table = pa.table(
        {"lap": pa.array([1, 57], pa.int64()), "time": [90.1, 91.2], "name": ["A", "B"]}
    )
    friendly = browser_friendly(table)
    assert friendly.schema.field("lap").type == pa.int32()
    assert friendly.schema.field("time").type == pa.float64()
    assert friendly.column("lap").to_pylist() == [1, 57]


def test_browser_friendly_refuses_to_truncate():
    with pytest.raises(pa.ArrowInvalid):
        browser_friendly(pa.table({"big": pa.array([2**40], pa.int64())}))


def test_export_writes_one_browser_friendly_file_per_query(tmp_path):
    client = FakeClient(pa.table({"n": pa.array([7], pa.int64())}))
    rows = export(tmp_path / "data", project="p", client=client)
    assert rows == {name: 1 for name in QUERIES}
    for name in QUERIES:
        table = pq.read_table(tmp_path / "data" / f"{name}.parquet")
        assert table.schema.field("n").type == pa.int32()
    assert all("`p.marts." in sql for sql in client.sql)


def test_export_copies_the_report_models_and_nothing_else():
    # The SQL lives in dbt (tested, documented, one grain each); the export is a plain copy.
    assert set(QUERIES) == {
        "races",
        "driver_races",
        "laps",
        "stints",
        "pit_stops",
        "tyre_wear",
        "undercuts",
        "neutralisations",
    }
    for name, sql in QUERIES.items():
        assert sql == f"select * from `{{project}}.marts.rpt_{name}`", name
        assert (TRANSFORM / "models/marts/reports" / f"rpt_{name}.sql").is_file(), name


def test_tyre_wear_offers_a_fuel_corrected_curve():
    # Cars get faster each lap as fuel burns: the corrected curve adds that back. The assumption
    # is one dbt variable, used by the model and published with the data.
    project = (TRANSFORM / "dbt_project.yml").read_text()
    fuel = float(re.search(r"^  fuel_s_per_lap: ([0-9.]+)$", project, re.M).group(1))
    assert 0.03 <= fuel <= 0.06
    model = (TRANSFORM / "models/marts/reports/rpt_tyre_wear.sql").read_text()
    assert "{{ var('fuel_s_per_lap') }} * laps.lap_number" in model
    assert "median_delta_fuel_corrected_s" in model
    assert "as fuel_s_per_lap" in model


def test_export_refuses_to_publish_an_empty_site(tmp_path):
    # An empty prod (e.g. just recreated) must fail the run so the last good site stays online.
    client = FakeClient(pa.table({"n": pa.array([], pa.int64())}))
    with pytest.raises(ValueError, match="races"):
        export(tmp_path / "data", project="p", client=client)


def test_export_refuses_a_site_with_races_but_no_results(tmp_path):
    # Half an export (a race list without anyone in it) is as broken as an empty one.
    class Client(FakeClient):
        def query(self, sql):
            self.table = pa.table(
                {"n": pa.array([] if "rpt_driver_races" in sql else [1], pa.int64())}
            )
            return super().query(sql)

    with pytest.raises(ValueError, match="driver_races"):
        export(tmp_path / "data", project="p", client=Client(None))
