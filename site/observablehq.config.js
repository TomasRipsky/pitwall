// pitwall's public site: https://tomasripsky.github.io/pitwall/ (ADR 0007).
export default {
  title: "pitwall",
  root: "src",
  base: "/pitwall/",
  style: "pitwall.css",
  // No third-party requests: drop Framework's default Google Fonts stylesheet (the site self-hosts its font).
  globalStylesheets: [],
  pages: [
    {name: "Race strategy", path: "/race-strategy"},
    {name: "Tyre wear", path: "/tyre-wear"},
    {name: "The undercut", path: "/undercut"},
    {name: "About the data", path: "/about"}
  ],
  footer:
    'pitwall by Tomas Ripsky · <a href="https://github.com/TomasRipsky/pitwall">source on GitHub</a> · part of the <a href="https://tomasripsky.github.io/data-engineering-lab/">Data Engineering Lab</a>'
};
