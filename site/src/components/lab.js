// Building blocks shared by every Data Engineering Lab project site (copied from the lab's
// template). pitwall's own encodings (tyre compounds, team colours) live in f1.js and art.js.
import * as d3 from "npm:d3";

/** Lab colours: `accent` for the main series, `ink` for secondary ones. */
export const palette = {accent: "#2a9d8f", ink: "#264653", muted: "#8f8f8f"};

/** Arrow table → array of plain objects. */
export function rows(table) {
  return Array.from(table, (row) => row.toJSON());
}

/** Number formats used across the site. */
export const fmt = {
  count: d3.format(","),
  seconds: (s) => `${d3.format(".1f")(s)} s`,
  percent: d3.format(".0%")
};
