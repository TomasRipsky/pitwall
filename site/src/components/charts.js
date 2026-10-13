// The two race charts, used by the race explorer and the case file. Each is a function of the
// panel width, drawn through Framework's resize().
import * as Plot from "npm:@observablehq/plot";
import * as d3 from "npm:d3";
import {ink} from "./lab.js";
import {
  compoundColor,
  compoundLetter,
  labelledPeriods,
  lightCompounds,
  neutralisationFill,
  neutralisationOpacity,
  teamColor
} from "./f1.js";

const style = {background: "transparent", fontSize: "12px"};

/** Laps under the Safety Car, the Virtual Safety Car or a red flag, as background washes. */
function washes(racePeriods, y1, y2) {
  return [
    Plot.rect(racePeriods, {
      x1: (d) => d.from - 1,
      x2: "to",
      y1,
      y2,
      fill: {value: (d) => neutralisationFill[d.type], scale: null},
      fillOpacity: {value: (d) => neutralisationOpacity[d.type], scale: null}
    }),
    Plot.text(labelledPeriods(racePeriods), {
      x: (d) => (d.from - 1 + d.to) / 2,
      frameAnchor: "top",
      dy: -16,
      text: (d) => (d.type === "RED" ? "RED FLAG" : d.type),
      fill: ink.muted,
      fontWeight: 700
    })
  ];
}

/** Who ran which tyres, and when everyone stopped: one row per driver, in finishing order. */
export function strategyChart({drivers, stints, stops, racePeriods}, width) {
  const order = drivers.map((d) => d.name_acronym);
  const lastLap = d3.max(stints, (d) => d.last_lap) ?? 1;
  const labelled = stints.filter((d) => d.laps_in_stint >= 3);
  const letter = (light) => Plot.text(labelled.filter((d) => lightCompounds.has(d.compound) === light), {
    x: (d) => (d.first_lap - 1 + d.last_lap) / 2,
    y: "name_acronym",
    text: (d) => compoundLetter(d.compound),
    fill: light ? ink.surface : "#ffffff",
    fontWeight: 700
  });
  return Plot.plot({
    width,
    height: 26 * order.length + 72,
    marginLeft: 48,
    marginTop: 30,
    marginBottom: 42,
    style,
    x: {domain: [-2.5, lastLap], label: "Lap →", labelAnchor: "center", labelOffset: 36, grid: true, ticks: d3.ticks(0, lastLap, 10), tickFormat: "d"},
    y: {domain: order, label: null},
    color: compoundColor,
    marks: [
      Plot.rectX(racePeriods, {
        x1: (d) => d.from - 1,
        x2: "to",
        fill: {value: (d) => neutralisationFill[d.type], scale: null},
        fillOpacity: {value: (d) => neutralisationOpacity[d.type], scale: null}
      }),
      Plot.text(labelledPeriods(racePeriods), {
        x: (d) => (d.from - 1 + d.to) / 2,
        frameAnchor: "top",
        dy: -16,
        text: (d) => (d.type === "RED" ? "RED FLAG" : d.type),
        fill: ink.muted,
        fontWeight: 700
      }),
      Plot.dot(drivers, {x: -1.4, y: "name_acronym", r: 5, fill: {value: (d) => teamColor(d.team_colour_hex), scale: null}, title: "team_name"}),
      Plot.barX(stints, {
        x1: (d) => d.first_lap - 1,
        x2: "last_lap",
        y: "name_acronym",
        fill: "compound",
        rx: 4,
        insetLeft: 1,
        insetRight: 1,
        insetTop: 3,
        insetBottom: 3,
        channels: {
          Driver: "full_name",
          Team: "team_name",
          Stint: "stint_number",
          Laps: "laps_in_stint",
          "Tyre age at start": "tyre_age_at_start",
          "Wear (s/lap)": "degradation_s_per_lap"
        },
        tip: {format: {x1: false, x2: false, y: false, fill: true}}
      }),
      letter(true),
      letter(false),
      Plot.dot(stops, {
        x: "lap_number",
        y: "name_acronym",
        symbol: "diamond",
        r: 5,
        fill: {value: (d) => (d.is_under_neutralisation ? ink.surface : ink.text), scale: null},
        stroke: {value: (d) => (d.is_under_neutralisation ? ink.text : ink.surface), scale: null},
        strokeWidth: 2,
        channels: {
          "Pit lane (s)": "pit_lane_time_s",
          "Stationary (s)": "stationary_time_s",
          Tyres: (d) => `${d.compound_before ?? "?"} → ${d.compound_after ?? "?"}`,
          Under: (d) => d.neutralisation ?? "green flag"
        },
        tip: {format: {fill: false, stroke: false}}
      })
    ]
  });
}

/** The lap chart: every driver's position at the end of each lap, from the grid (lap 0) to the flag.
 * Team-mates share a colour, so the second one is dashed and every line ends in the driver's code.
 * With `highlight` (a car number) one driver is drawn in colour over a grey field. */
export function lapChart({drivers, laps, stops = [], racePeriods = [], highlight = null}, width) {
  const byNumber = new Map(drivers.map((d) => [d.driver_number, d]));
  const teams = new Set();
  const second = new Set();
  for (const d of drivers) {
    if (teams.has(d.team_name)) second.add(d.driver_number);
    else teams.add(d.team_name);
  }
  const data = [];
  for (const d of drivers) if (d.grid_position != null) data.push({driver_number: d.driver_number, lap_number: 0, position: d.grid_position});
  for (const l of laps) if (l.position != null && byNumber.has(l.driver_number)) data.push(l);
  if (!data.length) return null;
  // a line is drawn in data order: each driver's laps must be consecutive and ascending
  data.sort((a, b) => a.driver_number - b.driver_number || a.lap_number - b.lap_number);
  const who = (d) => byNumber.get(d.driver_number);
  const maxPos = Math.max(d3.max(data, (d) => d.position), drivers.length);
  const lastLap = d3.max(data, (d) => d.lap_number);
  const ends = d3.rollups(data, (v) => d3.greatest(v, (d) => d.lap_number), (d) => d.driver_number).map(([, d]) => d);
  const position = new Map(data.map((d) => [`${d.driver_number}-${d.lap_number}`, d.position]));
  const pits = stops
    .map((s) => ({...s, position: position.get(`${s.driver_number}-${s.lap_number}`)}))
    .filter((s) => s.position != null && (highlight == null || s.driver_number === highlight));
  const colour = (d) => (highlight != null && d.driver_number !== highlight ? "#5a5a6b" : teamColor(who(d).team_colour_hex));
  const line = (rowsOf, options) => Plot.line(rowsOf, {
    x: "lap_number",
    y: "position",
    z: "driver_number",
    stroke: colour,
    curve: "bump-x",
    ...options
  });
  const field = data.filter((d) => highlight == null || d.driver_number !== highlight);
  const star = highlight == null ? [] : data.filter((d) => d.driver_number === highlight);
  return Plot.plot({
    width,
    height: Math.max(340, 21 * maxPos + 70),
    marginLeft: 40,
    marginRight: 44,
    marginTop: 30,
    marginBottom: 42,
    style,
    color: {type: "identity"},
    x: {domain: [0, lastLap], label: "Lap →", labelAnchor: "center", labelOffset: 36, grid: true, tickFormat: "d"},
    y: {domain: [maxPos + 0.5, 0.5], ticks: d3.range(1, maxPos + 1), tickFormat: (p) => `P${p}`, label: null, tickSize: 0},
    marks: [
      ...washes(racePeriods, 0.5, maxPos + 0.5),
      line(field.filter((d) => !second.has(d.driver_number)), {strokeWidth: highlight == null ? 2 : 1.2, strokeOpacity: highlight == null ? 1 : 0.6}),
      line(field.filter((d) => second.has(d.driver_number)), {strokeWidth: highlight == null ? 2 : 1.2, strokeOpacity: highlight == null ? 1 : 0.6, strokeDasharray: "5 4"}),
      line(star, {strokeWidth: 3.5}),
      Plot.dot(pits, {x: "lap_number", y: "position", r: 4, fill: ink.surface, stroke: ink.text, strokeWidth: 1.5}),
      Plot.text(ends, {
        x: "lap_number",
        y: "position",
        text: (d) => who(d).name_acronym,
        dx: 8,
        textAnchor: "start",
        fill: (d) => (highlight != null && d.driver_number !== highlight ? ink.muted : ink.text),
        fontWeight: (d) => (d.driver_number === highlight ? 800 : 600)
      }),
      Plot.tip(data, Plot.pointer({
        x: "lap_number",
        y: "position",
        title: (d) => `${who(d).full_name} · ${who(d).team_name}\n${d.lap_number === 0 ? "Grid" : `Lap ${d.lap_number}`}: P${d.position}${d.compound ? `\n${d.compound[0]}${d.compound.slice(1).toLowerCase()} tyre, ${d.tyre_age_laps ?? "?"} laps old` : ""}`
      }))
    ]
  });
}
