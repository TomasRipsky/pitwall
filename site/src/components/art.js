// Original illustrations for pitwall (no official F1 imagery or logos).
import {html, svg} from "npm:htl";

/** Side view of a generic single-seater, wheels painted with soft (rear) and medium (front) sidewalls. */
export function car({livery = "#e10600"} = {}) {
  return svg`<svg class="pw-car" viewBox="0 0 560 170" role="img" aria-label="Illustration of a Formula 1 car">
    <defs>
      <linearGradient id="pw-livery" x1="0" x2="1" y1="0" y2="0">
        <stop offset="0" stop-color="#7a0300"/>
        <stop offset="0.45" stop-color=${livery} />
        <stop offset="1" stop-color="#ff3b30"/>
      </linearGradient>
      <linearGradient id="pw-speed" x1="0" x2="1">
        <stop offset="0" stop-color="#f0f0f0" stop-opacity="0"/>
        <stop offset="1" stop-color="#f0f0f0" stop-opacity="0.45"/>
      </linearGradient>
    </defs>
    <g stroke="url(#pw-speed)" stroke-width="3" stroke-linecap="round">
      <line x1="0" y1="72" x2="90" y2="72"/>
      <line x1="20" y1="94" x2="120" y2="94"/>
      <line x1="0" y1="116" x2="80" y2="116"/>
    </g>
    <path d="M104 50 h52 v11 h-52z" fill="#23232d"/>
    <path d="M118 61 h10 v44 h-10z" fill="#23232d"/>
    <path d="M110 131 H500 L512 138 H104 Z" fill="#0b0b10"/>
    <path d="M122 110 C150 90 204 80 250 80 L322 76 C352 72 374 80 398 88 L476 104 C496 108 514 114 524 122 L526 131 L118 131 Z"
      fill="url(#pw-livery)"/>
    <path d="M190 112 L384 106 L398 121 L186 124 Z" fill="#000" fill-opacity="0.28"/>
    <path d="M286 79 C298 58 334 56 354 70" fill="none" stroke="#23232d" stroke-width="7" stroke-linecap="round"/>
    <circle cx="316" cy="73" r="9" fill="#f0f0f0"/>
    <path d="M500 130 h56 v7 h-56z" fill="#23232d"/>
    <text x="428" y="117" font-size="19" font-weight="900" font-style="italic" fill="#f0f0f0"
      font-family="Titillium Web, system-ui, sans-serif">01</text>
    <g>
      <circle cx="160" cy="131" r="35" fill="#0b0b10"/>
      <circle cx="160" cy="131" r="25" fill="none" stroke="#e10600" stroke-width="4"/>
      <circle cx="160" cy="131" r="10" fill="#2e2e3d"/>
      <circle cx="470" cy="133" r="30" fill="#0b0b10"/>
      <circle cx="470" cy="133" r="21" fill="none" stroke="#ffd12e" stroke-width="4"/>
      <circle cx="470" cy="133" r="9" fill="#2e2e3d"/>
    </g>
  </svg>`;
}

/** The brand mark: a tyre seen from the side, soft-compound red. */
export function logo(size = 26) {
  return svg`<svg viewBox="0 0 32 32" width=${size} height=${size} aria-hidden="true">
    <circle cx="16" cy="16" r="15" fill="#0b0b10"/>
    <circle cx="16" cy="16" r="10.5" fill="none" stroke="#e10600" stroke-width="3.6"/>
    <circle cx="16" cy="16" r="4" fill="#f0f0f0"/>
  </svg>`;
}

/** Five start lights: they come on one by one and go out together (CSS animation). */
export function startLights() {
  return html`<div class="lights" role="img" aria-label="Five red start lights"><i></i><i></i><i></i><i></i><i></i></div>`;
}

/** The pipeline drawn as one lap of a circuit: each stage is a sector marker on the track.
 * Wide screens get the drawing; narrow ones the same stages as a list (the text would be unreadable). */
export function pipelineLap(stages) {
  // marker positions along the track outline below, clockwise from the start line
  const at = [[250, 350], [520, 350], [790, 350], [900, 215], [690, 80], [330, 80], [100, 215]];
  const label = [[0, 44, "middle"], [0, 44, "middle"], [0, 44, "middle"], [-30, -4, "end"], [0, -30, "middle"], [0, -30, "middle"], [30, -4, "start"]];
  const track = "M150 350 H820 Q900 350 900 270 V160 Q900 80 820 80 H560 L505 118 L450 80 H180 Q100 80 100 160 V270 Q100 350 180 350 Z";
  return html`<svg class="circuit" viewBox="0 0 1000 430" aria-hidden="true">
    <path class="tarmac" d=${track} />
    <path class="kerbs" d="M820 350 Q900 350 900 270 M900 160 Q900 80 820 80 M180 80 Q100 80 100 160 M100 270 Q100 350 180 350"/>
    <path class="centre" d=${track} />
    <g transform="translate(150 335)">${[0, 1, 2, 3].flatMap((c) => [0, 1, 2].map((r) => svg`<rect x=${c * 7} y=${r * 10} width="7" height="10" fill=${(c + r) % 2 ? "#0b0b10" : "#f0f0f0"} />`))}</g>
    ${stages.map(([name, detail], i) => svg`<g transform="translate(${at[i][0]} ${at[i][1]})">
      <circle class="stop" r="15"/><text class="sector" y="4.5">${i + 1}</text>
      <text x=${label[i][0]} y=${label[i][1]} text-anchor=${label[i][2]}>${name}</text>
      <text class="small" x=${label[i][0]} y=${label[i][1] + 17} text-anchor=${label[i][2]}>${detail}</text>
    </g>`)}
  </svg>
  <ol class="pw-lap" aria-label="The pipeline, stage by stage">${stages.map(([name, detail], i) => html`<li><span class="pw-sector">${i + 1}</span><strong>${name}</strong><small>${detail}</small></li>`)}</ol>`;
}
