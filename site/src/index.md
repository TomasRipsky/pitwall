---
title: pitwall — how Formula 1 races are won with tyres and pit stops
toc: false
---

```js
import "./components/fonts.js";
import {fmt, ink, median, rows, series} from "./components/lab.js";
import {compoundColor, periods, strategy, teamColor, teamDot, tyre, tyreLegend} from "./components/f1.js";
import {car, logo, pipelineLap, startLights} from "./components/art.js";
import {lapChart, strategyChart} from "./components/charts.js";
```

```js
// One Parquet file per dbt report model (transform/models/marts/reports): every number below is
// computed from these rows, in the browser.
const races = d3.sort(rows(await FileAttachment("data/races.parquet").parquet()), (d) => d.race_date);
const driverRaces = rows(await FileAttachment("data/driver_races.parquet").parquet());
const laps = rows(await FileAttachment("data/laps.parquet").parquet());
const stints = rows(await FileAttachment("data/stints.parquet").parquet());
const stops = rows(await FileAttachment("data/pit_stops.parquet").parquet());
const wear = rows(await FileAttachment("data/tyre_wear.parquet").parquet());
const undercuts = rows(await FileAttachment("data/undercuts.parquet").parquet());
const neutralised = rows(await FileAttachment("data/neutralisations.parquet").parquet());
```

```js
// Headline numbers. "Race" means the Sunday race: Sprints are a third of the distance and have no
// mandatory stop, so they are left out wherever the claim is about race strategy.
const dry = ["SOFT", "MEDIUM", "HARD"];
const gp = races.filter((d) => d.session_name === "Race");
const gpKeys = new Set(gp.map((d) => d.session_key));
const latest = races.at(-1);
const seasons = d3.extent(races, (d) => d.season);
const fuel = wear[0]?.fuel_s_per_lap ?? 0;

const greenStops = stops.filter((d) => d.source === "pit" && !d.is_under_neutralisation);
const pitLoss = median(greenStops.filter((d) => gpKeys.has(d.session_key)), (d) => d.pit_lane_time_s);
const finishers = driverRaces.filter((d) => gpKeys.has(d.session_key) && d.status === "Finished");
const stopShare = (test) => finishers.filter((d) => test(d.pit_stops)).length / finishers.length;
const gpStops = stops.filter((d) => gpKeys.has(d.session_key));
const neutralShare = gpStops.filter((d) => d.is_under_neutralisation).length / gpStops.length;
const wearOf = (compound) =>
  median(stints.filter((d) => d.compound === compound && gpKeys.has(d.session_key)), (d) => d.degradation_s_per_lap) + fuel;
const judged = undercuts.filter((d) => d.is_success != null);
const greenUndercuts = judged.filter((d) => !d.attacker_pitted_under_neutralisation);
const undercutRate = d3.mean(greenUndercuts, (d) => (d.is_success ? 1 : 0));
const withGrid = gp.filter((d) => d.grid_published && d.winner_grid_position != null);
const poleWins = withGrid.filter((d) => d.winner_grid_position === 1).length / withGrid.length;
const frontRowWins = withGrid.filter((d) => d.winner_grid_position <= 3).length / withGrid.length;
```

```js
// Race explorer: a season, then one of its races (the latest first).
const seasonInput = Inputs.select(d3.range(seasons[1], seasons[0] - 1, -1), {label: "Season", format: String});
const season = Generators.input(seasonInput);
```

```js
const raceInput = Inputs.select(races.filter((d) => d.season === season).reverse(), {
  label: "Race",
  format: (d) => `${d.meeting_name} · ${d.session_name}`
});
const race = Generators.input(raceInput);
```

```js
const inRace = (d) => d.session_key === race.session_key;
const raceDrivers = d3.sort(driverRaces.filter(inRace), (d) => d.finish_position ?? 99, (d) => d.grid_position ?? 99);
const raceView = {
  drivers: raceDrivers,
  stints: stints.filter(inRace),
  stops: stops.filter(inRace),
  laps: laps.filter(inRace),
  racePeriods: periods(neutralised.filter(inRace))
};
const resultTable = Inputs.table(
  raceDrivers.map((d) => ({
    Finish: d.finish_position ?? d.status,
    Driver: d.full_name,
    Team: d,
    Grid: d.grid_position ?? "—",
    "Places gained": d.positions_gained,
    Stops: d.pit_stops,
    Tyres: d.tyres,
    "Typical lap": d.median_clean_lap_s
  })),
  {
    select: false,
    rows: 24,
    format: {
      Team: (d) => teamDot(d.team_name, d.team_colour_hex),
      "Places gained": (x) => (x == null ? "—" : x > 0 ? `+${x}` : `${x}`),
      Tyres: (t) => strategy(t),
      "Typical lap": (s) => fmt.seconds2(s)
    }
  }
);
```

```js
// Tyres --------------------------------------------------------------------------------------
const circuits = ["All circuits", ...d3.sort(new Set(wear.map((d) => d.circuit_short_name).filter((c) => c !== "All circuits")))];
const circuitInput = Inputs.select(circuits, {label: "Circuit"});
const circuit = Generators.input(circuitInput);
const fuelInput = Inputs.toggle({label: "Correct for fuel burn", value: true});
const corrected = Generators.input(fuelInput);
```

```js
function wearChart(width) {
  const y = corrected ? "median_delta_fuel_corrected_s" : "median_delta_s";
  const data = d3.sort(wear.filter((d) => d.circuit_short_name === circuit), (d) => d.tyre_age_laps);
  return Plot.plot({
    width,
    height: 380,
    marginBottom: 42,
    style: {background: "transparent", fontSize: "12px"},
    x: {label: "Tyre age (laps) →", labelAnchor: "center", labelOffset: 36, grid: true},
    y: {label: "↑ Slower than the stint's average (s)", grid: true, tickFormat: "+.1f"},
    color: compoundColor,
    marks: [
      Plot.ruleY([0], {stroke: "#6b6b7b"}),
      Plot.line(data, {x: "tyre_age_laps", y, stroke: "compound", strokeWidth: 2, curve: "monotone-x"}),
      Plot.dot(data, {x: "tyre_age_laps", y, fill: "compound", r: 4, stroke: ink.surface, strokeWidth: 2, channels: {"Laps measured": "laps"}, tip: true})
    ]
  });
}

// How long a set lasts: the middle half of all race stints on each compound, and the median.
const stintLengths = dry.map((compound) => {
  const lengths = stints.filter((d) => d.compound === compound && gpKeys.has(d.session_key)).map((d) => d.laps_in_stint);
  return {compound, q1: d3.quantile(lengths, 0.25), median: d3.median(lengths), q3: d3.quantile(lengths, 0.75), stints: lengths.length};
});
function stintLengthChart(width) {
  return Plot.plot({
    width,
    height: 190,
    marginLeft: 70,
    marginBottom: 42,
    style: {background: "transparent", fontSize: "12px"},
    x: {label: "Laps on one set →", labelAnchor: "center", labelOffset: 36, grid: true, domain: [0, d3.max(stintLengths, (d) => d.q3) + 6]},
    y: {label: null, domain: dry, tickFormat: (c) => c[0] + c.slice(1).toLowerCase()},
    color: compoundColor,
    marks: [
      Plot.barX(stintLengths, {x1: "q1", x2: "q3", y: "compound", fill: "compound", rx: 4, insetTop: 8, insetBottom: 8, channels: {Stints: "stints"}, tip: true}),
      Plot.tickX(stintLengths, {x: "median", y: "compound", stroke: ink.surface, strokeWidth: 3, insetTop: 8, insetBottom: 8}),
      Plot.text(stintLengths, {x: "q3", y: "compound", text: (d) => `median ${d.median} laps`, dx: 10, textAnchor: "start", fill: ink.soft})
    ]
  });
}

// Which tyres each circuit is raced on: share of race laps by compound.
const circuitLaps = d3
  .rollups(stints.filter((d) => gpKeys.has(d.session_key) && dry.includes(d.compound)), (v) => d3.sum(v, (d) => d.laps_in_stint), (d) => d.circuit_short_name, (d) => d.compound)
  .flatMap(([circuit, byCompound]) => {
    const total = d3.sum(byCompound, ([, n]) => n);
    return byCompound.map(([compound, n]) => ({circuit, compound, share: n / total}));
  });
const hardest = d3.sort(new Set(circuitLaps.map((d) => d.circuit)), (c) => -(circuitLaps.find((d) => d.circuit === c && d.compound === "HARD")?.share ?? 0));
function circuitTyresChart(width) {
  return Plot.plot({
    width,
    height: 22 * hardest.length + 50,
    marginLeft: 130,
    marginBottom: 42,
    style: {background: "transparent", fontSize: "12px"},
    x: {label: "Share of race laps →", labelAnchor: "center", labelOffset: 36, percent: true},
    y: {label: null, domain: hardest},
    color: compoundColor,
    marks: [
      Plot.barX(circuitLaps, Plot.stackX({x: "share", y: "circuit", fill: "compound", order: ["HARD", "MEDIUM", "SOFT"], insetLeft: 1, insetRight: 1, insetTop: 2, insetBottom: 2, tip: {format: {x: (v) => `${(100 * v).toFixed(0)}%`}}}))
    ]
  });
}
```

```js
// Pit stops ----------------------------------------------------------------------------------
const pitByCircuit = d3
  .rollups(greenStops, (v) => ({seconds: d3.median(v, (d) => d.pit_lane_time_s), stops: v.length}), (d) => d.circuit_short_name)
  .map(([circuit, s]) => ({circuit, ...s}))
  .filter((d) => d.stops >= 10);
function pitLossChart(width) {
  return Plot.plot({
    width,
    height: 22 * pitByCircuit.length + 50,
    marginLeft: 130,
    marginRight: 50,
    marginBottom: 42,
    style: {background: "transparent", fontSize: "12px"},
    x: {label: "Seconds in the pit lane (median, green flag) →", labelAnchor: "center", labelOffset: 36, grid: true},
    y: {label: null},
    marks: [
      Plot.barX(pitByCircuit, {y: "circuit", x: "seconds", sort: {y: "x"}, fill: series[0], rx: 4, insetTop: 2, insetBottom: 2, channels: {Stops: "stops"}, tip: true}),
      Plot.text(pitByCircuit, {y: "circuit", x: "seconds", text: (d) => d.seconds.toFixed(1), dx: 6, textAnchor: "start", fill: ink.soft}),
      Plot.ruleX([0], {stroke: "#6b6b7b"})
    ]
  });
}

// The crew's part: the seconds the car stands still. Published by the source from 2024.
const crews = d3
  .rollups(stops.filter((d) => d.stationary_time_s != null), (v) => ({seconds: d3.median(v, (d) => d.stationary_time_s), stops: v.length, colour: v.at(-1).team_colour_hex}), (d) => d.team_name)
  .map(([team, s]) => ({team, ...s}))
  .filter((d) => d.stops >= 15);
function crewChart(width) {
  return Plot.plot({
    width,
    height: 26 * crews.length + 50,
    marginLeft: 130,
    marginRight: 50,
    marginBottom: 42,
    style: {background: "transparent", fontSize: "12px"},
    color: {type: "identity"},
    x: {label: "Seconds stationary (median) →", labelAnchor: "center", labelOffset: 36, grid: true},
    y: {label: null},
    marks: [
      Plot.barX(crews, {y: "team", x: "seconds", sort: {y: "x"}, fill: (d) => teamColor(d.colour), rx: 4, insetTop: 3, insetBottom: 3, channels: {Stops: "stops"}, tip: {format: {fill: false}}}),
      Plot.text(crews, {y: "team", x: "seconds", text: (d) => d.seconds.toFixed(2), dx: 6, textAnchor: "start", fill: ink.soft}),
      Plot.ruleX([0], {stroke: "#6b6b7b"})
    ]
  });
}

const cheapBySeason = d3
  .rollups(gpStops, (v) => ({share: v.filter((d) => d.is_under_neutralisation).length / v.length, stops: v.length}), (d) => d.season)
  .map(([season, s]) => ({season: String(season), ...s}))
  .sort((a, b) => a.season.localeCompare(b.season));
function cheapStopsChart(width) {
  return Plot.plot({
    width,
    height: 240,
    style: {background: "transparent", fontSize: "12px"},
    x: {label: null, type: "band", paddingInner: 0.55},
    y: {label: "↑ Stops made while the race was neutralised (%)", percent: true, grid: true},
    marks: [
      Plot.barY(cheapBySeason, {x: "season", y: "share", fill: series[0], rx: 4, channels: {"Stops that season": "stops"}, tip: true}),
      Plot.text(cheapBySeason, {x: "season", y: "share", text: (d) => fmt.percent(d.share), dy: -10, fill: ink.text, fontWeight: 700}),
      Plot.ruleY([0], {stroke: "#6b6b7b"})
    ]
  });
}
```

```js
// The undercut -------------------------------------------------------------------------------
const greenInput = Inputs.toggle({label: "Only stops under green flag", value: true});
const greenOnly = Generators.input(greenInput);
```

```js
const attempts = (greenOnly ? greenUndercuts : judged).map((d) => ({...d, success: d.is_success ? 1 : 0}));
const rateBy = (key, minimum = 1) =>
  d3
    .rollups(attempts, (v) => ({rate: d3.mean(v, (d) => d.success), attempts: v.length}), key)
    .map(([k, s]) => ({key: String(k), ...s}))
    .filter((d) => d.attempts >= minimum);
function rateChart(data, width, {horizontal = false, label = null} = {}) {
  const value = {label: horizontal ? "It worked (%) →" : "↑ It worked (%)", percent: true, domain: [0, 100], grid: true};
  const text = (d) => `${fmt.percent(d.rate)} · ${d.attempts}`;
  return horizontal
    ? Plot.plot({
        width,
        height: 26 * data.length + 50,
        marginLeft: 130,
        marginRight: 70,
        marginBottom: 42,
        style: {background: "transparent", fontSize: "12px"},
        x: {...value, labelAnchor: "center", labelOffset: 36},
        y: {label: null},
        marks: [
          Plot.barX(data, {y: "key", x: "rate", sort: {y: "-x"}, fill: series[0], rx: 4, insetTop: 3, insetBottom: 3, channels: {Attempts: "attempts"}, tip: true}),
          Plot.text(data, {y: "key", x: "rate", text, dx: 6, textAnchor: "start", fill: ink.soft}),
          Plot.ruleX([0], {stroke: "#6b6b7b"})
        ]
      })
    : Plot.plot({
        width,
        height: 250,
        marginBottom: 42,
        style: {background: "transparent", fontSize: "12px"},
        x: {label, labelAnchor: "center", labelOffset: 36, type: "band", paddingInner: 0.55},
        y: value,
        marks: [
          Plot.barY(data, {x: "key", y: "rate", fill: series[0], rx: 4, channels: {Attempts: "attempts"}, tip: true}),
          Plot.text(data, {x: "key", y: "rate", text, dy: -10, fill: ink.text, fontWeight: 700}),
          Plot.ruleY([0], {stroke: "#6b6b7b"})
        ]
      });
}
```

```js
// Grid and finish ----------------------------------------------------------------------------
const classified = driverRaces.filter((d) => gpKeys.has(d.session_key) && d.grid_position != null && d.finish_position != null && d.grid_position <= 20 && d.finish_position <= 20);
const gridCells = d3.rollups(classified, (v) => v.length, (d) => d.grid_position, (d) => d.finish_position).flatMap(([grid, byFinish]) => byFinish.map(([finish, drivers]) => ({grid, finish, drivers})));
const held = classified.filter((d) => Math.abs(d.grid_position - d.finish_position) <= 2).length / classified.length;
function gridChart(width) {
  const size = Math.min(width, 560);
  return Plot.plot({
    width: size,
    height: size,
    marginLeft: 46,
    marginBottom: 44,
    padding: 0.06,
    style: {background: "transparent", fontSize: "12px"},
    x: {label: "Started →", labelAnchor: "center", labelOffset: 38, domain: d3.range(1, 21), tickFormat: (p) => `P${p}`, tickSize: 0},
    y: {label: "↑ Finished", domain: d3.range(1, 21), tickFormat: (p) => `P${p}`, tickSize: 0},
    color: {type: "sqrt", range: ["#22283a", "#3987e5", "#d6e6ff"], interpolate: "rgb", legend: true, label: "Drivers"},
    marks: [
      Plot.cell(gridCells, {x: "grid", y: "finish", fill: "drivers", rx: 2, tip: {format: {x: (p) => `P${p}`, y: (p) => `P${p}`}}})
    ]
  });
}
const winsFrom = d3.rollups(withGrid, (v) => v.length, (d) => Math.min(d.winner_grid_position, 6)).map(([grid, wins]) => ({grid, wins}));
function winsChart(width) {
  return Plot.plot({
    width,
    height: 250,
    marginBottom: 42,
    style: {background: "transparent", fontSize: "12px"},
    x: {label: "Where the winner started", labelAnchor: "center", labelOffset: 36, type: "band", domain: [1, 2, 3, 4, 5, 6], tickFormat: (p) => (p === 6 ? "P6 or lower" : `P${p}`), paddingInner: 0.45},
    y: {label: "↑ Races won", grid: true},
    marks: [
      Plot.barY(winsFrom, {x: "grid", y: "wins", fill: series[0], rx: 4, tip: true}),
      Plot.text(winsFrom, {x: "grid", y: "wins", text: "wins", dy: -10, fill: ink.text, fontWeight: 700}),
      Plot.ruleY([0], {stroke: "#6b6b7b"})
    ]
  });
}
const byTrack = d3
  .rollups(withGrid, (v) => ({pole: v.filter((d) => d.winner_grid_position === 1).length / v.length, races: v.length}), (d) => (d.circuit_type === "Permanent" ? "Permanent tracks" : "Street and road circuits"))
  .map(([kind, s]) => ({kind, ...s}));
```

```js
// Case file: the race won from furthest back. Chosen by the data, never by hand.
const caseRace = d3.greatest(withGrid, (d) => d.winner_grid_position);
const inCase = (d) => d.session_key === caseRace.session_key;
const caseDrivers = d3.sort(driverRaces.filter(inCase), (d) => d.finish_position ?? 99);
const hero = caseDrivers.find((d) => d.driver_number === caseRace.winner_driver_number);
const heroLaps = d3.sort(laps.filter((d) => inCase(d) && d.driver_number === hero.driver_number && d.position != null), (d) => d.lap_number);
const caseStops = stops.filter(inCase);
const heroStops = d3.sort(caseStops.filter((d) => d.driver_number === hero.driver_number), (d) => d.lap_number);
const casePeriods = periods(neutralised.filter(inCase));
const firstLead = heroLaps.find((d) => d.position === 1);
const lastNotLeading = heroLaps.findLast((d) => d.position !== 1);
const afterLapOne = heroLaps.find((d) => d.lap_number === 1);
const kinds = {SC: "the Safety Car", VSC: "the Virtual Safety Car", RED: "a red flag"};
const interruptions = casePeriods.map((p) => `${kinds[p.type]} (${p.from === p.to ? `lap ${p.from}` : `laps ${p.from}–${p.to}`})`);
const caseView = {drivers: caseDrivers, laps: laps.filter(inCase), stops: caseStops, racePeriods: casePeriods, highlight: hero.driver_number};
```

<header class="top">
  <a class="brand" href="#top" aria-label="pitwall, back to the top">${logo()} pitwall</a>
  <nav aria-label="Sections">
    <a href="#answer">The answers</a>
    <a href="#race">Race explorer</a>
    <a href="#tyres">Tyres</a>
    <a href="#pits">Pit stops</a>
    <a href="#undercut">Undercut</a>
    <a href="#grid">Grid</a>
    <a href="#pipeline">Pipeline</a>
    <a class="bi-link" href="./bi">BI</a>
    <a class="gh" href="https://github.com/TomasRipsky/pitwall">GitHub ↗</a>
  </nav>
</header>

<section class="hero" id="top">
  <div class="hero-grid">
    <div class="hero-copy">
      <p class="eyebrow">Formula 1 · race strategy · every race since ${seasons[0]}</p>
      <h1>How are races won with <em>tyres</em> and <em>pit stops</em>?</h1>
      <p class="lede">The fastest car does not always win. Teams decide which tyres to fit and when to stop for new ones, and a good call is worth more than raw speed. pitwall downloads every Formula 1 race, models it, and turns it into answers anyone can follow — no F1 knowledge needed.</p>
      <div class="stats" aria-live="polite">
        <div class="stat"><b>${fmt.count(races.length)}</b><span>races and sprints, ${seasons[0]}–${seasons[1]}</span></div>
        <div class="stat"><b>${fmt.count(laps.length)}</b><span>laps, one row each</span></div>
        <div class="stat"><b>${fmt.count(stops.length)}</b><span>pit stops</span></div>
        <div class="stat"><b>${latest.circuit_short_name}</b><span>latest: ${latest.meeting_name}, ${fmt.date(latest.race_date)}</span></div>
      </div>
    </div>
    <div class="hero-art">${startLights()}${car()}</div>
  </div>
  <div class="kerb" aria-hidden="true"></div>
</section>

<section id="answer" class="band">
<div class="wrap">
  <h2><span class="num"><i>01</i></span>The answers, on six pit boards</h2>
  <p class="sub">A pit board is the sign a team holds out from the pit wall to tell its driver what matters right now. These are the six things the data says matter most. Each is explained further down.</p>
  <div class="boards">
    <div class="board"><span class="plate">Pit loss</span><b>${fmt.one(pitLoss)}<small> s</small></b><p>is what a pit stop costs: the median time in the pit lane under normal racing. The tyre change itself takes under three seconds — the rest is driving slowly past the garages.</p></div>
    <div class="board"><span class="plate">Box</span><b>${fmt.percent(stopShare((n) => n === 1))}<small> once</small></b><p>of finishers stop exactly once, ${fmt.percent(stopShare((n) => n === 2))} twice and ${fmt.percent(stopShare((n) => n >= 3))} three times or more. With a stop that expensive, nobody makes one they can avoid.</p></div>
    <div class="board"><span class="plate">Tyre wear</span><b>+${wearOf("SOFT").toFixed(2)}<small> s/lap</small></b><p>is what a soft tyre loses every lap as it wears; a hard one loses +${wearOf("HARD").toFixed(2)} s. Soft is faster at first and gone sooner — that trade is the whole game.</p></div>
    <div class="board"><span class="plate">Undercut</span><b>${fmt.percent(undercutRate)}</b><p>of the time, pitting before the car ahead gets you past it. Fresh tyres are quick, but usually not quick enough: ${fmt.count(greenUndercuts.length)} attempts measured.</p></div>
    <div class="board"><span class="plate">Safety Car</span><b>${fmt.percent(neutralShare)}</b><p>of all race stops are made while the race is neutralised. Everyone drives slowly then, so a stop costs far less — teams wait for it if they can.</p></div>
    <div class="board"><span class="plate">Pole</span><b>${fmt.percent(poleWins)}</b><p>of races are won from first on the grid, and ${fmt.percent(frontRowWins)} from the first three places. Strategy decides the rest.</p></div>
  </div>
  <p class="footnote">Race figures use the ${gp.length} full races; the ${races.length - gp.length} Sprints (a third of the distance, no mandatory stop) appear in the explorer and the BI page.</p>
</div>
</section>

<section id="race" class="wrap">
  <h2><span class="num"><i>02</i></span>Race explorer</h2>
  <p class="sub">Pick any race. The first chart is its <b>strategy</b>: each row is a driver, in finishing order; each coloured bar is a <b>stint</b> — the laps driven on one set of tyres, marked with the tyre's letter; white diamonds are pit stops. The second is the <b>lap chart</b>: every driver's position at the end of each lap, from the starting grid to the flag.</p>
  <div class="controls">${seasonInput}${raceInput}</div>
  <div class="panel">
    <h3>${race.meeting_name} ${race.season} · ${race.session_name} <small>${race.circuit_short_name}, ${fmt.date(race.race_date)} · won by ${race.winner_name ?? "—"}</small></h3>
    ${tyreLegend()}
    <div class="legend">
      <span><svg width="14" height="14"><path d="M7 1 L13 7 L7 13 L1 7 Z" fill="#f0f0f0"/></svg> Pit stop</span>
      <span><svg width="14" height="14"><path d="M7 1 L13 7 L7 13 L1 7 Z" fill="none" stroke="#f0f0f0" stroke-width="2"/></svg> Pit stop while neutralised</span>
      <span><span class="swatch" style="background: rgba(240,240,240,0.18)"></span> Safety Car / Virtual Safety Car</span>
      <span><span class="swatch" style="background: rgba(225,6,0,0.4)"></span> Red flag (race stopped)</span>
    </div>
    ${resize((width) => strategyChart(raceView, width))}
  </div>
  <div class="panel mt">
    <h3>Lap chart <small>position at the end of each lap · team colours, the second driver of a team dashed · dots are pit stops</small></h3>
    ${resize((width) => lapChart(raceView, width) ?? html`<p class="empty">The source has no positions for this race.</p>`)}
  </div>
  <div class="panel mt">
    <h3>Result <small>“typical lap” is the median of the driver's clean laps</small></h3>
    ${resultTable}
  </div>
  <p class="footnote">Stops made under the Safety Car or a red flag cost much less time, so they are drawn hollow. Some ${seasons[0]} races have no official pit data: their stops are inferred from tyre changes and have no timing (this race: <b>${race.pit_timing}</b>). Sprint grids are often not published by the source, so their lap chart starts at lap 1.</p>
</section>

<section id="tyres" class="band">
<div class="wrap">
  <h2><span class="num"><i>03</i></span>Tyres: fast or lasting, never both</h2>
  <p class="sub">There are three dry-weather tyres. <b>Soft</b> grips best and wears out soonest; <b>hard</b> is slower and lasts; <b>medium</b> sits between. As a tyre wears, each lap gets slower. To see that wear we compare every clean lap with the average of the same driver's stint — which removes how fast the car and driver are — and take the median at each tyre age.</p>
  <div class="controls">${circuitInput}${fuelInput}</div>
  <div class="panel">
    <h3>${circuit}: how much slower each lap gets <small>${corrected ? "fuel-corrected" : "raw lap times"}</small></h3>
    ${tyreLegend(dry)}
    ${resize((width) => wearChart(width))}
  </div>
  <p class="footnote">Cars also get lighter as they burn fuel — about ${fuel} s faster every lap — which hides the wear. Switch the correction off to see how much: on many circuits the raw lines point <i>down</i>. The correction is an assumption (roughly 1.8 kg of fuel per lap at 0.03 s per kg), the same for every car and circuit. Each point needs at least five laps.</p>
  <div class="grid2 mt">
    <div class="panel">
      <h3>How long a set lasts <small>middle half of all race stints, and the median</small></h3>
      ${resize((width) => stintLengthChart(width))}
    </div>
    <div class="panel">
      <h3>Wear per lap, all circuits <small>median race stint, fuel-corrected</small></h3>
      <div class="tiles" style="margin: 1.2rem 0 0">
        ${dry.map((c) => html`<div class="tile"><b>+${wearOf(c).toFixed(3)}</b><span>${tyre(c, 18)} ${c[0] + c.slice(1).toLowerCase()} · s per lap</span></div>`)}
      </div>
    </div>
  </div>
  <div class="panel mt">
    <h3>What each circuit is raced on <small>share of race laps by tyre, hardest-wearing circuits first</small></h3>
    ${tyreLegend(dry)}
    ${resize((width) => circuitTyresChart(width))}
  </div>
  <p class="footnote">A circuit raced mostly on hard tyres is one that destroys soft ones: long fast corners, rough tarmac or heat. Wet-weather tyres are left out of this chart.</p>
</div>
</section>

<section id="pits" class="wrap">
  <h2><span class="num"><i>04</i></span>Pit stops: twenty seconds you never get back</h2>
  <p class="sub">A stop has two parts. The <b>pit lane</b> has a speed limit, so driving through it costs time however good the crew is — and how much depends on the circuit. The <b>stationary time</b> is the crew's part: lifting the car and changing four wheels.</p>
  <div class="grid2">
    <div class="panel">
      <h3>The price of a stop, by circuit <small>median seconds in the pit lane under green flag</small></h3>
      ${resize((width) => pitLossChart(width))}
    </div>
    <div>
      <div class="panel">
        <h3>Fastest crews <small>median seconds stationary · the source publishes it from 2024</small></h3>
        ${resize((width) => crewChart(width))}
      </div>
      <div class="panel mt">
        <h3>Waiting for the cheap stop <small>share of race stops made while neutralised</small></h3>
        ${resize((width) => cheapStopsChart(width))}
      </div>
    </div>
  </div>
  <p class="footnote">Circuits with fewer than 10 timed stops and teams with fewer than 15 are left out. Where the pit lane is long the whole strategy changes: a stop that costs 30 seconds is worth avoiding in a way a 19-second one is not. Bars are in the team's own colour, with the name beside them.</p>
</section>

<section id="undercut" class="band">
<div class="wrap">
  <h2><span class="num"><i>05</i></span>The undercut: does pitting first work?</h2>
  <p class="sub">Overtaking on track is hard, so teams try to pass in the pits. The <b>undercut</b> is the classic move.</p>
  <div class="steps">
    <div class="step"><div class="track"><span class="carB">B ahead</span><span class="carA">A behind</span></div><b>1 · Stuck behind</b><p>A is faster but cannot get past B on track.</p></div>
    <div class="step"><div class="track"><span class="carB">B stays out</span><span class="pit">PIT</span><span class="carA">A stops</span></div><b>2 · A pits first</b><p>On fresh tyres A laps much faster than B, who is still on worn ones.</p></div>
    <div class="step"><div class="track"><span class="carA">A ahead?</span><span class="pit">PIT</span><span class="carB">B stops</span></div><b>3 · B answers</b><p>When B stops one to three laps later, has A gained enough to come out in front?</p></div>
  </div>
  <div class="controls">${greenInput}</div>
  <div class="tiles">
    <div class="tile"><b>${fmt.percent(d3.mean(attempts, (d) => d.success))}</b><span>of attempts worked</span></div>
    <div class="tile"><b>${fmt.count(attempts.length)}</b><span>attempts measured</span></div>
    <div class="tile"><b>${fmt.count(attempts.filter((d) => d.success).length)}</b><span>places gained this way</span></div>
  </div>
  <div class="grid2">
    <div class="panel">
      <h3>By how long the rival waited <small>laps between the two stops · % worked · attempts</small></h3>
      ${resize((width) => rateChart(d3.sort(rateBy((d) => d.laps_between_stops), (d) => d.key), width, {label: "Laps the rival stayed out"}))}
    </div>
    <div class="panel">
      <h3>By season <small>% worked · attempts</small></h3>
      ${resize((width) => rateChart(d3.sort(rateBy((d) => d.season), (d) => d.key), width))}
    </div>
  </div>
  <div class="panel mt">
    <h3>By team <small>teams with 8 or more attempts · % worked · attempts</small></h3>
    ${resize((width) => rateChart(rateBy((d) => d.attacker_team, 8), width, {horizontal: true}))}
  </div>
  <p class="footnote">An attempt is counted when the car directly ahead pits one to three laps after the attacker. Only positions are used, not the time gaps between cars, and the rival may have had reasons of their own to stop. Stops during a red flag are excluded; stops under a Safety Car are hidden by default because everyone pits together then.</p>
</div>
</section>

<section id="grid" class="wrap">
  <h2><span class="num"><i>06</i></span>Does the grid decide the race?</h2>
  <p class="sub">The <b>grid</b> is the starting order, set by the fastest laps in Saturday's qualifying. If strategy mattered little, everyone would finish where they started. Each square counts the drivers who started in one place and finished in another: the brighter diagonal is “finished where they started”.</p>
  <div class="grid2">
    <div class="panel">
      <h3>Started here, finished there <small>${fmt.count(classified.length)} classified race finishes</small></h3>
      ${resize((width) => gridChart(width))}
    </div>
    <div>
      <div class="tiles">
        <div class="tile"><b>${fmt.percent(held)}</b><span>finish within two places of where they started</span></div>
        ${byTrack.map((d) => html`<div class="tile"><b>${fmt.percent(d.pole)}</b><span>${d.kind}: won from pole (${d.races} races)</span></div>`)}
      </div>
      <div class="panel">
        <h3>Where winners start <small>${withGrid.length} races with a published grid</small></h3>
        ${resize((width) => winsChart(width))}
      </div>
    </div>
  </div>
  <p class="footnote">Only classified finishers of full races with a published grid are counted, so retirements — the biggest way to lose places — are not in the picture. Grid penalties are already applied in the source's grid.</p>
</section>

<section id="case" class="band">
<div class="wrap">
  <h2><span class="num"><i>07</i></span>Case file: won from P${hero.grid_position}</h2>
  <p class="sub">The win from furthest back in the data — chosen by a query, not by us: the ${caseRace.meeting_name} ${caseRace.season} at ${caseRace.circuit_short_name}.</p>
  <div class="case">
    <div>
      <span class="big">P${hero.grid_position} → P1</span>
      <p><b>${hero.full_name}</b> (${hero.team_name}) started ${hero.grid_position === caseDrivers.length ? "last" : `${hero.grid_position}th of ${caseDrivers.length}`} and won.</p>
      <ol>
        ${afterLapOne ? html`<li>After the first lap: <b>P${afterLapOne.position}</b>.</li>` : ""}
        ${interruptions.length ? html`<li>The race was neutralised ${interruptions.length === 1 ? "once" : `${interruptions.length} times`}: ${interruptions.join(", ")}.</li>` : html`<li>The race ran without a Safety Car or red flag.</li>`}
        <li>${heroStops.length === 0 ? "No pit stop recorded." : html`Pit stops: ${heroStops.map((s) => `lap ${s.lap_number}${s.is_under_neutralisation ? " (while neutralised)" : ""}`).join(", ")} — tyres ${strategy(hero.tyres)}.`}</li>
        ${firstLead ? html`<li>First led on <b>lap ${firstLead.lap_number}</b>${lastNotLeading && lastNotLeading.lap_number > firstLead.lap_number ? html`; in front for good from lap ${lastNotLeading.lap_number + 1}` : ""}.</li>` : ""}
        <li>Typical lap ${fmt.seconds2(hero.median_clean_lap_s)}: ${hero.pace_gap_pct < 0 ? html`<b>${Math.abs(hero.pace_gap_pct).toFixed(1)}% faster</b> than the field's` : `${hero.pace_gap_pct.toFixed(1)}% slower than the field's`}.</li>
      </ol>
      <p class="verdict">Read the chart with the list: places won at once across a shaded band came from a stoppage or a cheap stop; places won one at a time on a clear track came from pace. A red flag lets everyone change tyres for free and closes every gap — it is the great reset.</p>
    </div>
    <div class="panel">
      <h3>${hero.name_acronym} against the field <small>position by lap · dots are ${hero.name_acronym}'s pit stops</small></h3>
      ${resize((width) => lapChart(caseView, width))}
    </div>
  </div>
  <p class="footnote">Everything in this section is computed from the exported rows of that race: if a later race is won from further back, the case changes by itself at the next pipeline run.</p>
</div>
</section>

<section id="pipeline" class="wrap">
  <h2><span class="num"><i>08</i></span>The pipeline: one lap of the data</h2>
  <p class="sub">Every Monday morning after a Grand Prix, a scheduled job drives this lap once: from the public API to this page. Nothing here is computed by hand, and no key or password exists anywhere in it.</p>
  <div class="panel">
    ${pipelineLap([
      ["OpenF1 API", "public · 30 requests a minute"],
      ["Ingest", "Python · checked against a contract"],
      ["Raw lake", "Parquet on GCS · success markers"],
      ["Load", "BigQuery raw · full reload"],
      ["Transform", "dbt · staging → marts"],
      ["Reports", "rpt_* tables · tested"],
      ["Site", "export → build → GitHub Pages"]
    ])}
  </div>
  <div class="grid2 mt">
    <div class="box">
      <h3>What each stage guarantees</h3>
      <ul class="check yes">
        <li><b>Ingest</b> waits for the API's rate limit instead of hitting it, and re-running a weekend never duplicates data: a marker file is written last, so half-written weekends are never read.</li>
        <li><b>The lake</b> is the source of truth: the warehouse can be rebuilt from it at any time without calling the API.</li>
        <li><b>dbt</b> states what one row is in every model, and tests it. Impossible values stop the run; the site keeps its last good version.</li>
        <li><b>The site</b> is built from exported files by a job with no cloud permissions at all.</li>
      </ul>
    </div>
    <div class="box">
      <h3>Built with</h3>
      <table class="stack">
        <tr><td>Ingestion</td><td>Python, httpx, pyarrow</td></tr>
        <tr><td>Storage</td><td>Google Cloud Storage (Parquet), BigQuery</td></tr>
        <tr><td>Transformation</td><td>dbt</td></tr>
        <tr><td>Orchestration</td><td>GitHub Actions: weekly schedule, CI on every pull request</td></tr>
        <tr><td>Infrastructure</td><td>Terraform, Workload Identity Federation (no keys)</td></tr>
        <tr><td>Site</td><td>Observable Framework, Observable Plot</td></tr>
        <tr><td>Cost</td><td>0 per month: everything fits the free tiers, with a budget alert and a query quota</td></tr>
      </table>
    </div>
  </div>
</section>

<section id="decisions" class="band">
<div class="wrap">
  <h2><span class="num"><i>09</i></span>Decisions worth explaining</h2>
  <p class="sub">Every durable choice is written down with its context and the alternatives that lost. The full records are in the repository.</p>
  <div class="grid3">
    <div class="box"><p class="adr"><a href="https://github.com/TomasRipsky/pitwall/blob/main/docs/decisions/0002-lake-first-custom-extractor.md">ADR 0002</a></p><h3>A lake first, and our own extractor</h3><p>Raw files are kept exactly as received, so every later step can be replayed. A small hand-written extractor teaches rate limiting and idempotency better than a connector hides them.</p></div>
    <div class="box"><p class="adr"><a href="https://github.com/TomasRipsky/pitwall/blob/main/docs/decisions/0004-full-reload-of-raw-tables.md">ADR 0004</a></p><h3>Reload everything, every time</h3><p>The data is megabytes, and BigQuery load jobs are free. Rebuilding the raw tables in full is simpler than tracking what changed and cannot drift.</p></div>
    <div class="box"><p class="adr"><a href="https://github.com/TomasRipsky/pitwall/blob/main/docs/decisions/0003-gcp-two-projects-bigquery-only.md">ADR 0003</a></p><h3>Two cloud projects</h3><p>Development and production share nothing: a mistake in one cannot touch the other, and each has its own budget alert.</p></div>
    <div class="box"><p class="adr"><a href="https://github.com/TomasRipsky/pitwall/blob/main/docs/decisions/0006-github-actions-as-orchestrator.md">ADR 0006</a></p><h3>GitHub Actions as the scheduler</h3><p>One weekly job does not need a workflow engine running all week. Runs are public, free, and log in to the cloud with short-lived identities.</p></div>
    <div class="box"><p class="adr"><a href="https://github.com/TomasRipsky/pitwall/blob/main/docs/decisions/0007-observable-framework-for-the-dashboard.md">ADR 0007</a></p><h3>A static site, not a BI server</h3><p>The site is files: nothing to keep running, nothing to pay for, and no credential near the public.</p></div>
    <div class="box"><p class="adr"><a href="https://github.com/TomasRipsky/pitwall/blob/main/docs/decisions/0008-showcase-site-story-and-bi.md">ADR 0008</a></p><h3>Report tables in dbt, a story and a BI page</h3><p>What the site shows is decided in tested SQL, one grain per table; the export only copies. The page tells the story, the BI page lets you slice it.</p></div>
  </div>
</div>
</section>

<section id="quality" class="wrap">
  <h2><span class="num"><i>10</i></span>Quality</h2>
  <p class="sub">A dashboard is only as good as what stops a wrong number from reaching it.</p>
  <div class="grid2">
    <div class="box">
      <h3>What is checked</h3>
      <ul class="check yes">
        <li><b>Over 70 Python tests</b> run without network or cloud: the extractor is tested against recorded answers of the real API.</li>
        <li><b>Over 130 dbt tests</b>: keys are unique, references exist, values are in range, and the racing rules (what counts as an undercut, how wear is measured) are pinned by unit tests.</li>
        <li><b>Every pull request</b> builds the models in throwaway datasets and builds this site before it can merge.</li>
        <li><b>Rows that fail</b> a data-quality rule are stored in an audit dataset, so a warning can be inspected instead of guessed at.</li>
      </ul>
    </div>
    <div class="box">
      <h3>What the source gets wrong, and what we do</h3>
      <ul class="check no">
        <li><b>Messages worded by hand.</b> Safety Car and red-flag messages change wording between seasons; unknown wordings raise a warning so they get added.</li>
        <li><b>No pit timing in some ${seasons[0]} races.</b> Stops are inferred from tyre changes and shown without timing.</li>
        <li><b>Broken stint records.</b> A few stints have missing or inverted lap ranges: reported, and kept out of the tyre statistics.</li>
        <li><b>Gaps in lap timing</b> (mostly lap 1 and pit laps) stay empty rather than being filled in.</li>
      </ul>
    </div>
  </div>
  <p class="footnote">How complete each race's data is — laps timed, pit timing official or inferred, grid published — is on the <a href="./bi#quality">BI page</a>.</p>
</section>

<section id="limits" class="band">
<div class="wrap">
  <h2><span class="num"><i>11</i></span>Limits, stated plainly</h2>
  <ul class="limits">
    <li><b>Positions, not gaps.</b> The undercut and the lap chart use the order of the cars, not the seconds between them.</li>
    <li><b>One fuel assumption.</b> The same correction for every car and circuit; real cars differ a little.</li>
    <li><b>Strategy is not the only reason.</b> A team may stop because of damage, a slow puncture or a penalty; the data cannot tell.</li>
    <li><b>Races and Sprints only.</b> Qualifying and practice are not modelled, and nothing here uses car telemetry.</li>
    <li><b>An unofficial source.</b> OpenF1 is a community API. It has gaps, and it changes; the pipeline documents and works around them rather than hiding them.</li>
  </ul>
</div>
</section>

<section class="wrap run" id="run">
  <h2><span class="num"><i>12</i></span>Run it yourself</h2>
  <p class="sub">The whole project — code, infrastructure, tests, decisions and this site — is public.</p>
<pre><span class="c"># the extractor against a local folder: no cloud account needed</span>
git clone https://github.com/TomasRipsky/pitwall.git && cd pitwall
make setup && make test
PITWALL_LAKE_URI=.lake make ingest ARGS="--meeting 1255"
<span class="c"># with a Google Cloud project (free tier): infrastructure, load, models, site</span>
make apply && make ingest ARGS="--season 2025" && make load && make transform && make site-preview</pre>
  <p><a class="btn" href="https://github.com/TomasRipsky/pitwall">Source on GitHub</a><a class="btn ghost" href="./bi">Explore the data (BI)</a><a class="btn ghost" href="https://tomasripsky.github.io/data-engineering-lab/">More projects</a></p>
</section>

<footer class="foot">
  <div class="wrap">
    <span>pitwall by Tomas Ripsky · data: <a href="https://openf1.org">OpenF1</a> · part of the <a href="https://tomasripsky.github.io/data-engineering-lab/">Data Engineering Lab</a></span>
    <span>Unofficial and not associated in any way with the Formula 1 companies. F1 and FORMULA 1 are trade marks of Formula One Licensing B.V. Illustrations are original.</span>
  </div>
</footer>
