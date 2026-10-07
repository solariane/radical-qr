#!/usr/bin/env node
/**
 * appstore-stats.mjs
 *
 * Pulls App Store Connect analytics (downloads, store discovery, purchases)
 * through the Analytics Reports API, with the same .p8 key as appstore-push.mjs.
 * No SDK in the app: these are Apple's own aggregated reports.
 *
 * Apple builds the reports asynchronously. A report request is made once per
 * app; the first daily instances show up 1–2 days later, then every day.
 * ONGOING gives daily files from the request on; ONE_TIME_SNAPSHOT backfills
 * the history once.
 *
 * Credentials, from the environment or ../.env: ASC_STATS_KEY_ID and
 * ASC_STATS_KEY_PATH (a "Sales and Reports" key, enough to download), falling
 * back to ASC_KEY_ID / ASC_KEY_PATH; ASC_ISSUER_ID is shared. Creating a report
 * request (`request`) needs an Admin key, once per app.
 *
 * Usage:
 *   node appstore-stats.mjs apps                      # list the account's apps
 *   node appstore-stats.mjs request                   # create ONGOING + snapshot requests (all apps)
 *   node appstore-stats.mjs status                    # requests and available reports per app
 *   node appstore-stats.mjs fetch [--app=<id|name>]   # download new daily files to marketing/stats/data
 *   node appstore-stats.mjs summary --report=downloads --from=2026-10-05 --to=2026-10-11
 *        [--app=<id|name>] [--by="Territory,Device,Source Type"] [--where="Download Type=First-time download"]
 *   node appstore-stats.mjs summary --report=downloads-detailed --by=Campaign --where="Campaign=google-mac-en"
 *
 * "Standard" reports are the daily backbone. The "Detailed" variants add
 * Source Info, Campaign (the ct= of a product-page link) and Page Title; Apple
 * produces them later and, for downloads, so far only weekly/monthly. Only DAILY
 * instances are saved: a weekly file would double-count the same rows.
 * Downloads mix First-time download, Auto-update, Redownload…: filter on
 * Download Type to count installs.
 */

import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import zlib from "node:zlib";
import { fileURLToPath } from "node:url";
import { createAscClient } from "./appstore/lib/asc.mjs";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const DATA_DIR = path.join(SCRIPT_DIR, "marketing", "stats", "data");

// The reports we keep, by the short name used on the command line.
const REPORTS = {
  downloads: "App Downloads Standard",
  discovery: "App Store Discovery and Engagement Standard",
  purchases: "App Store Purchases Standard",
  "downloads-detailed": "App Downloads Detailed",
  "discovery-detailed": "App Store Discovery and Engagement Detailed",
  "purchases-detailed": "App Store Purchases Detailed",
};

const [command = "status", ...rest] = process.argv.slice(2);
const args = Object.fromEntries(
  rest.filter((a) => a.startsWith("--")).map((a) => {
    const eq = a.indexOf("=");
    return eq === -1 ? [a.slice(2), true] : [a.slice(2, eq), a.slice(eq + 1)];
  })
);

// --- Credentials -----------------------------------------------------------

const envFile = path.join(SCRIPT_DIR, "..", ".env");
if (fs.existsSync(envFile)) {
  for (const line of fs.readFileSync(envFile, "utf8").split("\n")) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^["']|["']$/g, "");
  }
}
// The metadata key (ASC_*) cannot read analytics: a "Sales and Reports" key
// goes in ASC_STATS_* and wins when present.
const ISSUER_ID = process.env.ASC_STATS_ISSUER_ID || process.env.ASC_ISSUER_ID;
const KEY_ID = process.env.ASC_STATS_KEY_ID || process.env.ASC_KEY_ID;
let KEY_PATH = process.env.ASC_STATS_KEY_PATH || process.env.ASC_KEY_PATH;
if (KEY_PATH?.startsWith("~/")) KEY_PATH = path.join(os.homedir(), KEY_PATH.slice(2));

const fail = (m) => { console.error(`Error: ${m}`); process.exit(1); };
if (!ISSUER_ID || !KEY_ID || !KEY_PATH) {
  fail("ASC_STATS_KEY_ID + ASC_STATS_KEY_PATH (or ASC_KEY_ID + ASC_KEY_PATH) and ASC_ISSUER_ID are required (environment or ../.env).");
}

const asc = createAscClient({ issuerId: ISSUER_ID, keyId: KEY_ID, keyPath: KEY_PATH, fail });

// Follows `links.next` so a long list of instances comes back whole.
async function getAll(pathname) {
  const out = [];
  for (let next = pathname; next; ) {
    const page = await asc(next);
    out.push(...(page?.data ?? []));
    next = page?.links?.next ?? null;
  }
  return out;
}

const slug = (s) => s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");

async function listApps() {
  const apps = await getAll("/v1/apps?fields[apps]=name,bundleId&limit=200");
  const wanted = typeof args.app === "string" ? args.app.toLowerCase() : null;
  return apps
    .map((a) => ({ id: a.id, name: a.attributes.name, bundleId: a.attributes.bundleId }))
    .filter((a) => !wanted || a.id === wanted || a.name.toLowerCase().includes(wanted));
}

const requestsFor = (appId) =>
  getAll(`/v1/apps/${appId}/analyticsReportRequests?fields[analyticsReportRequests]=accessType,stoppedDueToInactivity`);

// --- Commands --------------------------------------------------------------

async function cmdApps() {
  for (const a of await listApps()) console.log(`${a.id}  ${a.name}  (${a.bundleId})`);
}

async function cmdRequest() {
  for (const app of await listApps()) {
    const existing = new Set((await requestsFor(app.id))
      .filter((r) => !r.attributes.stoppedDueToInactivity)
      .map((r) => r.attributes.accessType));
    for (const accessType of ["ONGOING", "ONE_TIME_SNAPSHOT"]) {
      if (existing.has(accessType)) { console.log(`${app.name}: ${accessType} already requested`); continue; }
      const res = await asc("/v1/analyticsReportRequests", {
        method: "POST",
        tolerate: [409],
        body: { data: {
          type: "analyticsReportRequests",
          attributes: { accessType },
          relationships: { app: { data: { type: "apps", id: app.id } } },
        } },
      });
      console.log(`${app.name}: ${accessType} ${res?.__error ? "already exists (409)" : "requested"}`);
    }
  }
}

async function reportsFor(requestId) {
  const reports = [];
  for (const name of Object.values(REPORTS)) {
    const found = await getAll(`/v1/analyticsReportRequests/${requestId}/reports?filter[name]=${encodeURIComponent(name)}`);
    reports.push(...found.map((r) => ({ id: r.id, name: r.attributes.name })));
  }
  return reports;
}

async function cmdStatus() {
  for (const app of await listApps()) {
    console.log(`\n${app.name} (${app.id})`);
    const requests = await requestsFor(app.id);
    if (!requests.length) { console.log("  no report request yet → node appstore-stats.mjs request"); continue; }
    for (const r of requests) {
      const stopped = r.attributes.stoppedDueToInactivity ? " (stopped: inactivity)" : "";
      console.log(`  ${r.attributes.accessType}${stopped}`);
      for (const rep of await reportsFor(r.id)) {
        const daily = await getAll(`/v1/analyticsReports/${rep.id}/instances?filter[granularity]=DAILY&limit=200`);
        const dates = daily.map((i) => i.attributes.processingDate).sort();
        console.log(`    ${rep.name}: ${daily.length} daily file(s)${dates.length ? `, ${dates[0]} → ${dates.at(-1)}` : ""}`);
      }
    }
  }
}

// One instance can hold several segments; each is a gzip'd TSV at a pre-signed URL.
async function downloadInstance(instanceId) {
  const segments = await getAll(`/v1/analyticsReportInstances/${instanceId}/segments`);
  let header = null;
  const rows = [];
  for (const seg of segments) {
    const res = await fetch(seg.attributes.url);
    if (!res.ok) fail(`segment download → HTTP ${res.status}`);
    const lines = zlib.gunzipSync(Buffer.from(await res.arrayBuffer())).toString("utf8").split("\n").filter(Boolean);
    header ??= lines[0];
    rows.push(...lines.slice(1));
  }
  return header ? [header, ...rows].join("\n") + "\n" : "";
}

async function cmdFetch() {
  let written = 0;
  for (const app of await listApps()) {
    for (const request of await requestsFor(app.id)) {
      for (const rep of await reportsFor(request.id)) {
        const short = Object.keys(REPORTS).find((k) => REPORTS[k] === rep.name);
        const dir = path.join(DATA_DIR, slug(app.name), short);
        fs.mkdirSync(dir, { recursive: true });
        const instances = await getAll(`/v1/analyticsReports/${rep.id}/instances?filter[granularity]=DAILY&limit=200`);
        for (const inst of instances) {
          // ONGOING and the snapshot may both carry a date: the first one saved wins.
          const file = path.join(dir, `${inst.attributes.processingDate}.tsv`);
          if (fs.existsSync(file)) continue;
          fs.writeFileSync(file, await downloadInstance(inst.id));
          written += 1;
        }
      }
    }
  }
  console.log(`${written} new file(s) in ${path.relative(SCRIPT_DIR, DATA_DIR)}`);
}

// Sums the "Counts" column (and "Unique Counts" when present) over the saved
// files, grouped by the requested columns. Rows are filtered on their own Date,
// not on the file's processing date.
function cmdSummary() {
  const short = args.report || "downloads";
  if (!REPORTS[short]) fail(`--report must be one of ${Object.keys(REPORTS).join(", ")}`);
  const by = (typeof args.by === "string" ? args.by : "Territory,Device,Source Type").split(",").map((s) => s.trim());
  const where = typeof args.where === "string"
    ? args.where.split(",").map((w) => w.split("=").map((s) => s.trim()))
    : [];
  const from = args.from || "0000-00-00";
  const to = args.to || "9999-99-99";
  const wantedApp = typeof args.app === "string" ? args.app.toLowerCase() : null;

  if (!fs.existsSync(DATA_DIR)) fail("no data yet → node appstore-stats.mjs fetch");
  const totals = new Map();
  const seen = new Set();
  for (const appDir of fs.readdirSync(DATA_DIR)) {
    if (wantedApp && !appDir.includes(slug(wantedApp))) continue;
    const dir = path.join(DATA_DIR, appDir, short);
    if (!fs.existsSync(dir)) continue;
    for (const file of fs.readdirSync(dir).filter((f) => f.endsWith(".tsv"))) {
      const [head, ...lines] = fs.readFileSync(path.join(dir, file), "utf8").split("\n").filter(Boolean);
      const cols = head.split("\t");
      const idx = (c) => cols.indexOf(c);
      for (const c of [...by, ...where.map(([c]) => c)]) {
        if (idx(c) === -1) fail(`column "${c}" not in ${short} (columns: ${cols.join(", ")})`);
      }
      for (const line of lines) {
        // A snapshot and a daily file can overlap: count each row once.
        if (seen.has(`${appDir}\t${line}`)) continue;
        seen.add(`${appDir}\t${line}`);
        const v = line.split("\t");
        const date = v[idx("Date")];
        if (date < from || date > to) continue;
        if (where.some(([c, val]) => v[idx(c)] !== val)) continue;
        const key = [appDir, ...by.map((c) => v[idx(c)] || "—")].join("\t");
        const t = totals.get(key) ?? { counts: 0, unique: 0 };
        t.counts += Number(v[idx("Counts")]) || 0;
        if (idx("Unique Counts") !== -1) t.unique += Number(v[idx("Unique Counts")]) || 0;
        totals.set(key, t);
      }
    }
  }
  const rows = [...totals].sort((a, b) => b[1].counts - a[1].counts);
  console.log(["app", ...by, "Counts", "Unique Counts"].join("\t"));
  for (const [key, t] of rows) console.log(`${key}\t${t.counts}\t${t.unique || ""}`);
}

const COMMANDS = { apps: cmdApps, request: cmdRequest, status: cmdStatus, fetch: cmdFetch, summary: cmdSummary };
if (!COMMANDS[command]) fail(`unknown command "${command}" (${Object.keys(COMMANDS).join(", ")})`);
await COMMANDS[command]();
