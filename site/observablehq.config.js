// pitwall's public site: https://tomasripsky.github.io/pitwall/ (ADR 0007, ADR 0008).
// One long story page (index.md) and a BI page (bi.md): the layout lives in the pages and in
// src/components/lab.css, so Framework's own chrome (sidebar, pager, header, footer) is off.
export default {
  title: "pitwall",
  root: "src",
  base: "/pitwall/",
  style: "pitwall.css",
  // No third-party requests: drop Framework's default Google Fonts stylesheet (the site self-hosts its font).
  globalStylesheets: [],
  head:
    '<meta name="theme-color" content="#15151e"><link rel="icon" href="data:image/svg+xml,%3Csvg xmlns=%27http://www.w3.org/2000/svg%27 viewBox=%270 0 32 32%27%3E%3Ccircle cx=%2716%27 cy=%2716%27 r=%2715%27 fill=%27%230b0b10%27/%3E%3Ccircle cx=%2716%27 cy=%2716%27 r=%2710.5%27 fill=%27none%27 stroke=%27%23e10600%27 stroke-width=%273.6%27/%3E%3Ccircle cx=%2716%27 cy=%2716%27 r=%274%27 fill=%27%23f0f0f0%27/%3E%3C/svg%3E">',
  pages: [],
  sidebar: false,
  pager: false,
  toc: false,
  header: "",
  footer: ""
};
