// Screenshots routes in headless Chromium, to compare a screen with its design:
//
//   pnpm shot [--theme light|dark] [--size 1440x900] [--out dir] /route ...
//
// Starts Vite in-process and saves <out>/<route>-<theme>.png (plus -<size> when
// it isn't the default), printing the page's console errors as it goes.
// CHROME_PATH picks the browser; the default is the newest Chromium that
// Playwright downloaded into ~/.cache/ms-playwright.
import { readdirSync } from "node:fs";
import { mkdir } from "node:fs/promises";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import { parseArgs } from "node:util";
import { chromium } from "playwright-core";
import { createServer } from "vite";

const DEFAULT_SIZE = "1440x900";

const { values, positionals: routes } = parseArgs({
  allowPositionals: true,
  options: {
    theme: { type: "string", default: "light" },
    size: { type: "string", default: DEFAULT_SIZE },
    out: { type: "string", default: join(tmpdir(), "iris-shots") },
  },
});
const { theme, size, out } = values;
const [width, height] = size.split("x").map(Number);
if ((theme !== "light" && theme !== "dark") || !width || !height || routes.length === 0) {
  console.error("usage: pnpm shot [--theme light|dark] [--size WxH] [--out dir] /route ...");
  process.exit(2);
}

const server = await createServer({
  root: join(import.meta.dirname, ".."),
  server: { port: 0, hmr: false },
  logLevel: "warn",
});
await server.listen();
const { port } = server.httpServer.address();
const browser = await chromium.launch({ executablePath: chromePath() });
await mkdir(out, { recursive: true });
try {
  for (const route of routes) {
    const page = await browser.newPage({ viewport: { width, height }, colorScheme: theme });
    page.on("console", (message) => {
      if (message.type() !== "error") return;
      const { url } = message.location();
      console.error(`${route}: console error: ${message.text()}${url ? ` (${url})` : ""}`);
    });
    page.on("pageerror", (error) => console.error(`${route}: page error: ${error.message}`));
    await page.goto(`http://localhost:${port}/#${route}`, { waitUntil: "networkidle" });
    await page.evaluate(() => document.fonts.ready);
    const file = join(out, `${slug(route)}-${theme}${size === DEFAULT_SIZE ? "" : `-${size}`}.png`);
    // Animations stop at their first frame, so shots are stable (skeletons, spinners).
    await page.screenshot({ path: file, fullPage: true, animations: "disabled" });
    console.log(file);
    await page.close();
  }
} finally {
  await browser.close();
  await server.close();
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

/** `/console/hosts?mock=empty` → `console-hosts-mock-empty`. */
function slug(route) {
  return route.replace(/[^a-z0-9]+/gi, "-").replace(/^-+|-+$/g, "") || "index";
}
