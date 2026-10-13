---
title: BI — Formula 1 race strategy, sliced your way
toc: false
---

```js
import "./components/fonts.js";
import {downloadButton, emptyState, fmt, ink, median, rows, series} from "./components/lab.js";
import {compoundColor, strategy, teamColor, teamDot, tyre, tyreLegend} from "./components/f1.js";
import {logo} from "./components/art.js";
```

```js
// The same Parquet files as the story page (one per dbt report model). They are small enough to
// filter in memory: no query engine is shipped to the browser.
const races = d3.sort(rows(await FileAttachment("data/races.parquet").parquet()), (d) => d.race_date);
const driverRaces = rows(await FileAttachment("data/driver_races.parquet").parquet());
const stints = rows(await FileAttachment("data/stints.parquet").parquet());
const stops = rows(await FileAttachment("data/pit_stops.parquet").parquet());
const undercuts = rows(await FileAttachment("data/undercuts.parquet").parquet());
const fuel = rows(await FileAttachment("data/tyre_wear.parquet").parquet())[0]?.fuel_s_per_lap ?? 0;
```

```js
// The filter bar: every block below reads these four values.
const all = "All";
const seasonInput = Inputs.select([all, ...d3.sort(new Set(races.map((d) => d.season)), (d) => -d)], {label: "Season", format: String});
// Races by default: a Sprint is a third of the distance with no mandatory stop and often no published
// grid, so mixing the two would blur wins, stops per finisher and places gained.
const sessionInput = Inputs.radio(["Race", "Sprint", all], {label: "Session", value: "Race", format: (d) => (d === all ? "Both" : d)});
const circuitInput = Inputs.select([all, ...d3.sort(new Set(races.map((d) => d.circuit_short_name)))], {label: "Circuit"});
const teamInput = Inputs.select([all, ...d3.sort(new Set(driverRaces.map((d) => d.team_name)))], {label: "Team"});
const season = Generators.input(seasonInput);
const session = Generators.input(sessionInput);
const circuit = Generators.input(circuitInput);
const team = Generators.input(teamInput);
```

```js
// A race matches season, session and circuit; a row about a driver or a stop also matches the team.
const raceOk = (d) => (season === all || d.season === season) && (session === all || d.session_name === session) && (circuit === all || d.circuit_short_name === circuit);
const teamOk = (name) => team === all || name === team;
const fRaces = races.filter(raceOk);
const fDrivers = driverRaces.filter((d) => raceOk(d) && teamOk(d.team_name));
const fStints = stints.filter((d) => raceOk(d) && teamOk(d.team_name));
const fStops = stops.filter((d) => raceOk(d) && teamOk(d.team_name));
const fUndercuts = undercuts.filter((d) => raceOk(d) && teamOk(d.attacker_team) && d.is_success != null && !d.attacker_pitted_under_neutralisation);
const scope = [season === all ? "all seasons" : season, session === all ? "races and sprints" : `${session.toLowerCase()}s`, circuit === all ? null : circuit, team === all ? null : team].filter(Boolean).join(" · ");
const dry = ["SOFT", "MEDIUM", "HARD"];
const share = (list, test) => (list.length ? list.filter(test).length / list.length : null);
const mean = (list, accessor) => {
  const m = d3.mean(list, (d) => accessor(d) ?? NaN);
  return m === undefined ? null : m;
};
// a sum of nothing is unknown, not zero (Sprints rarely have a grid, so no places gained)
const sumKnown = (list, accessor) => {
  const known = list.map(accessor).filter((x) => x != null);
  return known.length ? d3.sum(known) : null;
};
const signedCount = (x) => (x == null ? "—" : x > 0 ? `+${x}` : x < 0 ? `−${-x}` : "0");
```

```js
// KPIs
const greenTimed = fStops.filter((d) => d.source === "pit" && !d.is_under_neutralisation);
const kpiTiles = html`<div class="kpis">
  <div class="kpi"><span>${session === all ? "Races and sprints" : `${session}s`}</span><b>${fmt.count(fRaces.length)}</b><small>${team === all ? `${fmt.count(d3.sum(fRaces, (d) => d.laps))} laps of racing` : "a team does not narrow the race list"}</small></div>
  <div class="kpi"><span>Driver laps</span><b>${fmt.count(d3.sum(fDrivers, (d) => d.laps_completed ?? 0))}</b><small>${fmt.count(fDrivers.length)} starts by ${new Set(fDrivers.map((d) => d.full_name)).size} drivers</small></div>
  <div class="kpi"><span>Pit stops</span><b>${fmt.count(fStops.length)}</b><small>${fmt.percent(share(fStops, (d) => d.is_under_neutralisation))} while neutralised</small></div>
  <div class="kpi"><span>Pit-lane time</span><b>${fmt.seconds(median(greenTimed, (d) => d.pit_lane_time_s))}</b><small>median of ${fmt.count(greenTimed.length)} green-flag stops</small></div>
  <div class="kpi"><span>Stationary time</span><b>${fmt.seconds2(median(fStops, (d) => d.stationary_time_s))}</b><small>median · published from 2024</small></div>
  <div class="kpi"><span>Undercut success</span><b>${fmt.percent(share(fUndercuts, (d) => d.is_success))}</b><small>${fmt.count(fUndercuts.length)} green-flag attempts${team === all ? "" : " by this team"}</small></div>
</div>`;
```

```js
// Drivers ------------------------------------------------------------------------------------
const driverRows = d3
  .rollups(fDrivers, (v) => {
    const last = d3.greatest(v, (d) => d.race_date);
    return {
      Driver: last.full_name,
      Team: last,
      Starts: v.length,
      Wins: v.filter((d) => d.finish_position === 1).length,
      Podiums: v.filter((d) => d.finish_position != null && d.finish_position <= 3).length,
      Points: d3.sum(v, (d) => d.points ?? 0),
      "Avg grid": mean(v, (d) => d.grid_position),
      "Avg finish": mean(v, (d) => d.finish_position),
      "Places gained": sumKnown(v, (d) => d.positions_gained),
      "Pace gap %": median(v, (d) => d.pace_gap_pct),
      DNF: v.filter((d) => d.status === "DNF").length
    };
  }, (d) => d.full_name)
  .map(([, d]) => d)
  .sort((a, b) => b.Points - a.Points || b.Wins - a.Wins);
const driverTable = Inputs.table(driverRows, {
  select: false,
  rows: 16,
  sort: "Points",
  reverse: true,
  format: {
    Team: (d) => teamDot(d.team_name, d.team_colour_hex),
    "Avg grid": (x) => fmt.one(x),
    "Avg finish": (x) => fmt.one(x),
    "Places gained": signedCount,
    "Pace gap %": (x) => fmt.signed(x)
  }
});
const driverCsv = driverRows.map((d) => ({...d, Team: d.Team.team_name}));
function pointsChart(width) {
  const top = driverRows.filter((d) => d.Points > 0).slice(0, 15);
  if (!top.length) return emptyState("points");
  return Plot.plot({
    width,
    height: 24 * top.length + 50,
    marginLeft: 150,
    marginRight: 50,
    marginBottom: 42,
    style: {background: "transparent", fontSize: "12px"},
    color: {type: "identity"},
    x: {label: "Points →", labelAnchor: "center", labelOffset: 36, grid: true},
    y: {label: null, domain: top.map((d) => d.Driver)},
    marks: [
      Plot.barX(top, {y: "Driver", x: "Points", fill: (d) => teamColor(d.Team.team_colour_hex), rx: 4, insetTop: 3, insetBottom: 3, channels: {Team: (d) => d.Team.team_name, Wins: "Wins", Podiums: "Podiums"}, tip: {format: {fill: false}}}),
      Plot.text(top, {y: "Driver", x: "Points", text: (d) => fmt.count(d.Points), dx: 6, textAnchor: "start", fill: ink.soft}),
      Plot.ruleX([0], {stroke: "#6b6b7b"})
    ]
  });
}
```

```js
// Teams --------------------------------------------------------------------------------------
const teamRows = d3
  .rollups(fDrivers, (v) => {
    const name = v[0].team_name;
    const teamStops = fStops.filter((d) => d.team_name === name);
    const attempts = fUndercuts.filter((d) => d.attacker_team === name);
    return {
      Team: d3.greatest(v, (d) => d.race_date),
      Points: d3.sum(v, (d) => d.points ?? 0),
      Wins: v.filter((d) => d.finish_position === 1).length,
      Podiums: v.filter((d) => d.finish_position != null && d.finish_position <= 3).length,
      "Places gained": sumKnown(v, (d) => d.positions_gained),
      "Pit stops": teamStops.length,
      "Stationary (s)": median(teamStops, (d) => d.stationary_time_s),
      "Undercuts tried": attempts.length,
      "Undercuts worked": share(attempts, (d) => d.is_success)
    };
  }, (d) => d.team_name)
  .map(([, d]) => d)
  .sort((a, b) => b.Points - a.Points);
const teamTable = Inputs.table(teamRows, {
  select: false,
  rows: 16,
  format: {
    Team: (d) => teamDot(d.team_name, d.team_colour_hex),
    "Places gained": signedCount,
    "Stationary (s)": (x) => (x == null ? "—" : x.toFixed(2)),
    "Undercuts worked": (x) => fmt.percent(x)
  }
});
const teamCsv = teamRows.map((d) => ({...d, Team: d.Team.team_name}));
function seasonPointsChart(width) {
  const data = d3
    .rollups(fDrivers, (v) => ({points: d3.sum(v, (d) => d.points ?? 0), colour: d3.greatest(v, (d) => d.race_date).team_colour_hex}), (d) => d.season, (d) => d.team_name)
    .flatMap(([year, teams]) => teams.map(([name, s]) => ({season: String(year), team: name, ...s})))
    .filter((d) => d.points > 0);
  if (!data.length) return emptyState("points");
  const totals = d3.rollup(data, (v) => d3.sum(v, (d) => d.points), (d) => d.season);
  return Plot.plot({
    width,
    height: 360,
    marginBottom: 42,
    style: {background: "transparent", fontSize: "12px"},
    color: {type: "identity"},
    x: {label: null, type: "band", paddingInner: 0.35},
    y: {label: "↑ Points", grid: true},
    marks: [
      Plot.barY(data, Plot.stackY({x: "season", y: "points", z: "team", fill: (d) => teamColor(d.colour), order: "-sum", insetTop: 1, insetBottom: 1, channels: {Team: "team"}, tip: {format: {fill: false, z: false, x: true, y: true}}})),
      Plot.text(data, Plot.stackY({x: "season", y: "points", z: "team", order: "-sum", text: (d) => (d.points / totals.get(d.season) > 0.07 ? d.team : ""), fill: ink.text, stroke: ink.surface, strokeWidth: 4, fontWeight: 600})),
      Plot.ruleY([0], {stroke: "#6b6b7b"})
    ]
  });
}
```

```js
// Circuits -----------------------------------------------------------------------------------
const circuitRows = d3
  .rollups(fRaces, (v) => {
    const name = v[0].circuit_short_name;
    const keys = new Set(v.map((d) => d.session_key));
    const here = fStops.filter((d) => keys.has(d.session_key));
    const finishers = fDrivers.filter((d) => keys.has(d.session_key) && d.status === "Finished");
    const withGrid = v.filter((d) => d.grid_published && d.winner_grid_position != null);
    return {
      Circuit: name,
      Kind: v[0].circuit_type,
      Sessions: v.length,
      "Pit lane (s)": median(here.filter((d) => d.source === "pit" && !d.is_under_neutralisation), (d) => d.pit_lane_time_s),
      "Stops per finisher": mean(finishers, (d) => d.pit_stops),
      "Laps neutralised": d3.sum(v, (d) => d.neutralised_laps) / d3.sum(v, (d) => d.laps),
      "Won from pole": share(withGrid, (d) => d.winner_grid_position === 1),
      "Last winner": d3.greatest(v, (d) => d.race_date).winner_name ?? "—"
    };
  }, (d) => d.circuit_short_name)
  .map(([, d]) => d)
  .sort((a, b) => a.Circuit.localeCompare(b.Circuit));
const circuitTable = Inputs.table(circuitRows, {
  select: false,
  rows: 26,
  format: {
    "Pit lane (s)": (x) => fmt.one(x),
    "Stops per finisher": (x) => fmt.one(x),
    "Laps neutralised": (x) => fmt.percent(x),
    "Won from pole": (x) => fmt.percent(x)
  }
});
```

```js
// Tyres --------------------------------------------------------------------------------------
const tyreRows = ["SOFT", "MEDIUM", "HARD", "INTERMEDIATE", "WET"]
  .map((compound) => {
    const v = fStints.filter((d) => d.compound === compound);
    const wear = median(v, (d) => d.degradation_s_per_lap);
    return {
      Tyre: compound,
      Stints: v.length,
      "Laps run": d3.sum(v, (d) => d.laps_in_stint ?? 0),
      "Median stint (laps)": median(v, (d) => d.laps_in_stint),
      "Longest stint": d3.max(v, (d) => d.laps_in_stint) ?? null,
      "Wear (s/lap, fuel-corrected)": wear == null || !dry.includes(compound) ? null : wear + fuel
    };
  })
  .filter((d) => d.Stints > 0);
const tyreTable = Inputs.table(tyreRows, {
  select: false,
  format: {
    Tyre: (c) => html`<span style="display:inline-flex;gap:.4rem;align-items:center">${tyre(c, 18)} ${c[0] + c.slice(1).toLowerCase()}</span>`,
    "Laps run": (x) => fmt.count(x),
    "Longest stint": (x) => fmt.count(x),
    "Wear (s/lap, fuel-corrected)": (x) => (x == null ? "—" : `+${x.toFixed(3)}`)
  }
});
function startTyreChart(width) {
  const first = fStints.filter((d) => d.stint_number === 1 && dry.includes(d.compound));
  const data = d3
    .rollups(first, (v) => v.length, (d) => d.season, (d) => d.compound)
    .flatMap(([year, byCompound]) => {
      const total = d3.sum(byCompound, ([, n]) => n);
      return byCompound.map(([compound, n]) => ({season: String(year), compound, share: n / total, starts: n}));
    });
  if (!data.length) return emptyState("stints");
  return Plot.plot({
    width,
    height: 280,
    marginBottom: 42,
    style: {background: "transparent", fontSize: "12px"},
    x: {label: null, type: "band", paddingInner: 0.35},
    y: {label: "↑ Share of starts (%)", percent: true, grid: true},
    color: compoundColor,
    marks: [
      Plot.barY(data, Plot.stackY({x: "season", y: "share", fill: "compound", order: ["HARD", "MEDIUM", "SOFT"], insetTop: 1, insetBottom: 1, channels: {Starts: "starts"}, tip: {format: {y: (v) => `${(100 * v).toFixed(0)}%`}}})),
      Plot.ruleY([0], {stroke: "#6b6b7b"})
    ]
  });
}
```

```js
// Pit-stop log and data quality ----------------------------------------------------------------
const stopRows = d3
  .sort(fStops, (d) => d.race_date, (d) => d.lap_number)
  .reverse()
  .map((d) => ({
    Date: d.race_date,
    Race: `${d.meeting_name} · ${d.session_name}`,
    Driver: d.full_name,
    Team: d.team_name,
    Lap: d.lap_number,
    "Pit lane (s)": d.pit_lane_time_s,
    "Stationary (s)": d.stationary_time_s,
    Tyres: `${d.compound_before ?? "?"} → ${d.compound_after ?? "?"}`,
    Under: d.neutralisation ?? "green flag",
    "Position before": d.position_before,
    "Position after": d.position_after
  }));
const stopTable = Inputs.table(stopRows, {
  select: false,
  rows: 14,
  format: {"Pit lane (s)": (x) => fmt.one(x), "Stationary (s)": (x) => (x == null ? "—" : x.toFixed(2)), "Position before": (x) => x ?? "—", "Position after": (x) => x ?? "—"}
});
const qualityRows = d3
  .sort(fRaces, (d) => d.race_date)
  .reverse()
  .map((d) => ({
    Date: d.race_date,
    Race: `${d.meeting_name} · ${d.session_name}`,
    Drivers: d.drivers,
    Laps: d.laps,
    "Laps with a time": d.timed_laps_share,
    "Pit timing": d.pit_timing,
    "Grid published": d.grid_published ? "yes" : "no",
    "Neutralised laps": d.neutralised_laps
  }));
const qualityTable = Inputs.table(qualityRows, {select: false, rows: 14, format: {"Laps with a time": (x) => (x == null ? "—" : `${(100 * x).toFixed(1)}%`)}});
```

<header class="top" id="top">
  <a class="brand" href="./" aria-label="pitwall, the story">${logo()} pitwall <span class="badge">BI</span></a>
  <nav aria-label="Sections">
    <a href="#drivers">Drivers</a>
    <a href="#teams">Teams</a>
    <a href="#circuits">Circuits</a>
    <a href="#tyres">Tyres</a>
    <a href="#stops">Pit-stop log</a>
    <a href="#quality">Data quality</a>
    <a class="bi-link" href="./">The story</a>
    <a class="gh" href="https://github.com/TomasRipsky/pitwall">GitHub ↗</a>
  </nav>
</header>

<div class="filters">${seasonInput}${sessionInput}${circuitInput}${teamInput}</div>

<section class="wrap bi-head">
  <p class="eyebrow">Self-service · Formula 1 race strategy</p>
  <h1>Slice the races your way — <em>${scope}</em></h1>
  <p class="sub">Filter by season, kind of session, circuit and team: every number and table below follows the filters, and where one cannot, it says so. The figures are computed in your browser from the same tested tables as <a href="./">the story</a>; nothing is sent anywhere. Each table can be downloaded.</p>
  ${kpiTiles}
</section>

<section id="drivers" class="band">
<div class="wrap">
  <h2><span class="num"><i>D</i></span>Drivers</h2>
  <p class="sub"><b>Places gained</b> is grid position minus finishing position, added up. <b>Pace gap</b> compares the driver's typical clean lap with the whole field's in the same race: negative is faster than the field. Sprint grids are often unpublished, so Sprints add little to the grid columns.</p>
  <div class="panel">
    <h3>Points <small>top 15 in this selection · bars in the team's colour</small></h3>
    ${resize((width) => pointsChart(width))}
  </div>
  <div class="panel mt">
    <div class="table-head"><h3>Every driver <small>${fmt.count(driverRows.length)} in this selection</small></h3>${downloadButton(driverCsv, "pitwall-drivers.csv")}</div>
    ${driverRows.length ? driverTable : emptyState("drivers")}
  </div>
</div>
</section>

<section id="teams" class="wrap">
  <h2><span class="num"><i>T</i></span>Teams</h2>
  <p class="sub">What a team controls beyond the car: how fast its crew changes four wheels, and how often its strategists make the undercut work. A team that changed its name appears under each name it raced with.</p>
  <div class="panel">
    <h3>Points by season <small>each segment is a team, largest at the bottom · the larger ones are named, hover for the rest</small></h3>
    ${resize((width) => seasonPointsChart(width))}
  </div>
  <div class="panel mt">
    <div class="table-head"><h3>Every team <small>${fmt.count(teamRows.length)} in this selection</small></h3>${downloadButton(teamCsv, "pitwall-teams.csv")}</div>
    ${teamRows.length ? teamTable : emptyState("teams")}
  </div>
</section>

<section id="circuits" class="band">
<div class="wrap">
  <h2><span class="num"><i>C</i></span>Circuits</h2>
  <p class="sub">The same race is a different problem at each track: a long pit lane makes stops expensive, walls bring the Safety Car out, and where overtaking is hard the pole sitter usually wins. <b>Laps neutralised</b> is the share of laps run under a Safety Car, a Virtual Safety Car or a red flag.</p>
  <div class="panel">
    <div class="table-head"><h3>Every circuit <small>${team === all ? `${fmt.count(circuitRows.length)} in this selection` : "pit columns follow the team; the others do not"}</small></h3>${downloadButton(circuitRows, "pitwall-circuits.csv")}</div>
    ${circuitRows.length ? circuitTable : emptyState("circuits")}
  </div>
</div>
</section>

<section id="tyres" class="wrap">
  <h2><span class="num"><i>S</i></span>Tyres</h2>
  <p class="sub">A <b>stint</b> is the laps run on one set of tyres. Wear is the time lost per lap as the set ages, with the fuel correction explained in the story; it is only measured on the three dry tyres.</p>
  <div class="grid2">
    <div class="panel">
      <div class="table-head"><h3>By tyre</h3>${downloadButton(tyreRows, "pitwall-tyres.csv")}</div>
      ${tyreRows.length ? tyreTable : emptyState("stints")}
    </div>
    <div class="panel">
      <h3>The tyre drivers start on <small>share of first stints, by season</small></h3>
      ${tyreLegend(dry)}
      ${resize((width) => startTyreChart(width))}
    </div>
  </div>
</section>

<section id="stops" class="band">
<div class="wrap">
  <h2><span class="num"><i>P</i></span>Pit-stop log</h2>
  <p class="sub">Every stop in the selection, newest first. Stops inferred from a tyre change (some early races) have no timing.</p>
  <div class="panel">
    <div class="table-head"><h3>${fmt.count(stopRows.length)} stops</h3>${downloadButton(stopRows, "pitwall-pit-stops.csv")}</div>
    ${stopRows.length ? stopTable : emptyState("pit stops")}
  </div>
</div>
</section>

<section id="quality" class="wrap">
  <h2><span class="num"><i>Q</i></span>Data quality, race by race</h2>
  <p class="sub">How complete the source was for each race: the share of laps that have a time, whether pit stops were timed officially or inferred from tyre changes, and whether a starting grid was published. A number built on thin data should say so.</p>
  <div class="panel">
    <div class="table-head"><h3>${fmt.count(qualityRows.length)} sessions <small>${team === all ? "" : "a team does not narrow this table"}</small></h3>${downloadButton(qualityRows, "pitwall-data-quality.csv")}</div>
    ${qualityRows.length ? qualityTable : emptyState("sessions")}
  </div>
</section>

<footer class="foot">
  <div class="wrap">
    <span>pitwall by Tomas Ripsky · data: <a href="https://openf1.org">OpenF1</a> · <a href="./">the story</a> · part of the <a href="https://tomasripsky.github.io/data-engineering-lab/">Data Engineering Lab</a></span>
    <span>Unofficial and not associated in any way with the Formula 1 companies. F1 and FORMULA 1 are trade marks of Formula One Licensing B.V.</span>
  </div>
</footer>
