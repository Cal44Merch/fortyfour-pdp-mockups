#!/usr/bin/env node
// capture.mjs <url> <outdir> [maxPages=6]
// Playwright: full-page screenshots (desktop + mobile) of the entry URL plus
// key internal pages discovered from nav links, console errors, failed requests.
import fs from "node:fs";
import path from "node:path";
import { chromium, devices } from "playwright";

const [url, out, maxPagesArg] = process.argv.slice(2);
if (!url || !out) { console.error("usage: capture.mjs <url> <outdir> [maxPages]"); process.exit(1); }
const MAX_PAGES = Number(maxPagesArg) || 6;
const shots = path.join(out, "screenshots");
const raw = path.join(out, "raw");
fs.mkdirSync(shots, { recursive: true });
fs.mkdirSync(raw, { recursive: true });

const slug = (u) => (new URL(u).pathname.replace(/\W+/g, "-").replace(/^-|-$/g, "") || "home").slice(0, 60);
const origin = new URL(url).origin;
const consoleLog = [];
const failedRequests = [];

async function snap(browser, pageUrl, viewport, label) {
  const ctx = await browser.newContext(
    viewport === "mobile" ? { ...devices["iPhone 13"] } : { viewport: { width: 1440, height: 900 } }
  );
  const page = await ctx.newPage();
  page.on("console", (m) => { if (["error", "warning"].includes(m.type())) consoleLog.push({ page: pageUrl, type: m.type(), text: m.text().slice(0, 300) }); });
  page.on("requestfailed", (r) => failedRequests.push({ page: pageUrl, url: r.url().slice(0, 200), error: r.failure()?.errorText }));
  let links = [];
  try {
    await page.goto(pageUrl, { waitUntil: "networkidle", timeout: 45000 }).catch(() => page.waitForTimeout(3000));
    await page.waitForTimeout(1500); // settle lazy-loaded content
    await page.screenshot({ path: path.join(shots, `${slug(pageUrl)}--${label}.png`), fullPage: true });
    links = await page.$$eval("a[href]", (as) => as.map((a) => a.href));
  } catch (e) {
    consoleLog.push({ page: pageUrl, type: "capture-error", text: String(e).slice(0, 300) });
  }
  await ctx.close();
  return links;
}

const browser = await chromium.launch();
try {
  // Entry page, both viewports; collect internal links from desktop pass.
  const links = await snap(browser, url, "desktop", "desktop");
  await snap(browser, url, "mobile", "mobile");

  // Pick distinct internal pages (nav-level: shortest paths first).
  const internal = [...new Set(links.filter((l) => {
    try { const u = new URL(l); return u.origin === origin && !u.hash && u.pathname !== new URL(url).pathname; } catch { return false; }
  }))].sort((a, b) => a.length - b.length).slice(0, Math.max(0, MAX_PAGES - 1));

  for (const p of internal) {
    await snap(browser, p, "desktop", "desktop");
    await snap(browser, p, "mobile", "mobile");
  }

  const manifestPath = path.join(raw, "manifest.json");
  const manifest = fs.existsSync(manifestPath) ? JSON.parse(fs.readFileSync(manifestPath, "utf8")) : {};
  manifest.capture = {
    entry: url,
    pagesCaptured: [url, ...internal],
    screenshots: fs.readdirSync(shots),
    consoleIssues: consoleLog.length,
    failedRequests: failedRequests.length,
  };
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 1));
  fs.writeFileSync(path.join(raw, "console-log.json"), JSON.stringify(consoleLog, null, 1));
  fs.writeFileSync(path.join(raw, "failed-requests.json"), JSON.stringify(failedRequests, null, 1));
  console.log(`capture.mjs done: ${manifest.capture.screenshots.length} screenshots, ${consoleLog.length} console issues, ${failedRequests.length} failed requests`);
} finally {
  await browser.close();
}
