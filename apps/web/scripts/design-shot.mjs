// Renders a design artboard (a .dc.html file of the Iris UI canvas) to PNG, to
// compare with a `shot` of the matching route:
//
//   node scripts/design-shot.mjs <file.dc.html> <light|dark> <WxH> <out.png>
//
// An out file ending in .html gets the expanded page instead, to measure it.
// Runs the file's renderVals() in the page with this.props = {theme}, expands
// the <x-dc> template ({{dotted.path}} holes, <sc-for list as>, <sc-if value>),
// and swaps the Google Fonts link for the local Geist files. CHROME_PATH picks
// the browser, as in `shot`.
import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { chromium } from "playwright-core";

const [file, theme, size, out] = process.argv.slice(2);
const [width, height] = (size ?? "").split("x").map(Number);
if (!file || (theme !== "light" && theme !== "dark") || !width || !height || !out) {
  console.error("usage: node scripts/design-shot.mjs <file.dc.html> <light|dark> <WxH> <out.png>");
  process.exit(2);
}

const html = readFileSync(file, "utf8");
const xdc = html.match(/<x-dc>([\s\S]*)<\/x-dc>/)[1];
const helmet = (xdc.match(/<helmet>([\s\S]*?)<\/helmet>/)?.[1] ?? "").replace(/<link[^>]*fonts\.googleapis[^>]*>/g, "");
const template = xdc.replace(/<helmet>[\s\S]*?<\/helmet>/, "");
const script = html.match(/<script type="text\/x-dc"[^>]*>([\s\S]*?)<\/script>/)[1];
const fonts = fontCss("geist", "Geist") + fontCss("geist-mono", "Geist Mono");

const browser = await chromium.launch({ executablePath: chromePath() });
try {
  const page = await browser.newPage({ viewport: { width, height }, colorScheme: theme });
  page.on("pageerror", (error) => console.error(`page error: ${error.message}`));
  // The artboard's own code runs in the page, not in Node.
  const vals = await page.evaluate(
    ([src, theme]) => {
      // The artboard's class extends DCLogic; a plain base is enough to call renderVals().
      const Component = new Function("DCLogic", `${src}\nreturn Component;`)(Object);
      const component = new Component();
      component.props = { theme };
      return component.renderVals();
    },
    [script, theme],
  );
  const doc = `<!doctype html><html><head><meta charset="utf-8"><style>${fonts}</style>${helmet}</head><body>${expand(template, vals)}</body></html>`;
  if (out.endsWith(".html")) writeFileSync(out, doc);
  else {
    await page.setContent(doc);
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: out, fullPage: true, animations: "disabled" });
  }
  console.log(out);
} finally {
  await browser.close();
}

/** Expands the outermost <sc-for>/<sc-if> first, so loop variables reach nested holes. */
function expand(src, scope) {
  const open = /<sc-(for|if)\b([^>]*)>/.exec(src);
  if (!open) return fill(src, scope);
  const [tag, kind, attrs] = open;
  const tags = new RegExp(`<sc-${kind}\\b|</sc-${kind}>`, "g");
  tags.lastIndex = open.index + tag.length;
  let close;
  for (let depth = 1; depth > 0; ) {
    close = tags.exec(src);
    depth += close[0].startsWith("</") ? -1 : 1;
  }
  const body = src.slice(open.index + tag.length, close.index);
  const attr = (name) => attrs.match(new RegExp(`\\b${name}="([^"]*)"`))[1];
  const value = (name) => lookup(attr(name).replace(/^\{\{|\}\}$/g, ""), scope);
  const inner =
    kind === "if"
      ? value("value") ? expand(body, scope) : ""
      : value("list").map((item) => expand(body, { ...scope, [attr("as")]: item })).join("");
  return fill(src.slice(0, open.index), scope) + inner + expand(src.slice(close.index + close[0].length), scope);
}

function fill(src, scope) {
  return src.replace(/\{\{([\w.]+)\}\}/g, (_, path) =>
    String(lookup(path, scope) ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;"),
  );
}

function lookup(path, scope) {
  return path.split(".").reduce((value, key) => value?.[key], scope);
}

/** The package's @font-face rules under the family name the artboards use, with the fonts inlined. */
function fontCss(pkg, family) {
  const dir = join(import.meta.dirname, "..", "node_modules", "@fontsource-variable", pkg);
  return readFileSync(join(dir, "index.css"), "utf8")
    .replace(/font-family: '[^']+'/g, `font-family: '${family}'`)
    .replace(/url\(\.\/files\/([^)]+)\)/g, (_, name) => `url(data:font/woff2;base64,${readFileSync(join(dir, "files", name)).toString("base64")})`);
}

function chromePath() {
  if (process.env.CHROME_PATH) return process.env.CHROME_PATH;
  const cache = join(homedir(), ".cache", "ms-playwright");
  const [newest] = readdirSync(cache)
    .filter((name) => /^chromium-\d+$/.test(name))
    .sort((a, b) => Number(b.slice("chromium-".length)) - Number(a.slice("chromium-".length)));
  if (!newest) throw new Error(`No Chromium in ${cache}; set CHROME_PATH`);
  return join(cache, newest, "chrome-linux64", "chrome");
}
