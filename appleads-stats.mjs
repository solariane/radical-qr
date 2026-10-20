#!/usr/bin/env node
/**
 * appleads-stats.mjs
 *
 * Reads Apple Ads reports through the Apple Ads Platform API v1 (the Campaign
 * Management API v5 it replaced stops working on 26 January 2027).
 * Prints campaign, ad group, keyword and search-term totals for a period and
 * saves the raw JSON in marketing/stats/data/appleads/. Also lists keyword bids
 * and changes them (the API user needs the "API Campaign Manager" role for that).
 *
 * Auth: a client secret (JWT, ES256) signed with ../appleads_private_key.pem is
 * exchanged at appleid.apple.com for a one-hour access token.
 *
 * Credentials (environment or ../.env):
 *   ASA_CLIENT_ID, ASA_TEAM_ID, ASA_KEY_ID  — shown in Apple Ads → Account Settings → API
 *   ASA_KEY_PATH                           — the EC P-256 private key whose public half is uploaded there
 *   ASA_ORG_ID                             — the ad account id (`acls` lists it; same number as the old org id)
 *
 * Usage:
 *   node appleads-stats.mjs acls                              # check access, list ad accounts
 *   node appleads-stats.mjs report --from=2026-10-05 --to=2026-10-11
 *        [--levels=campaigns,adgroups,keywords,searchterms] [--campaign=<name part>]
 *   node appleads-stats.mjs bids [--campaign=<name part>]      # every keyword, its bid and status
 *   node appleads-stats.mjs set-bid --campaign="QR – DE" --adgroup=Intent --bid=0.70 [--match=EXACT] [--apply]
 *        # without --apply, only prints what would change
 *   node appleads-stats.mjs set-status --campaign="QR – AT" --status=PAUSED|ENABLED [--apply]
 */

import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const DATA_DIR = path.join(SCRIPT_DIR, "marketing", "stats", "data", "appleads");
const API = "https://api.ads.apple.com/v1";

const [command = "acls", ...rest] = process.argv.slice(2);
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
const fail = (m) => { console.error(`Error: ${m}`); process.exit(1); };
const { ASA_CLIENT_ID, ASA_TEAM_ID, ASA_KEY_ID, ASA_ORG_ID } = process.env;
let KEY_PATH = process.env.ASA_KEY_PATH;
if (KEY_PATH?.startsWith("~/")) KEY_PATH = path.join(os.homedir(), KEY_PATH.slice(2));
if (!ASA_CLIENT_ID || !ASA_TEAM_ID || !ASA_KEY_ID || !KEY_PATH || !ASA_ORG_ID) {
  fail("ASA_CLIENT_ID, ASA_TEAM_ID, ASA_KEY_ID, ASA_KEY_PATH and ASA_ORG_ID are required (environment or ../.env).");
}

const b64url = (buf) =>
  Buffer.from(buf).toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

function clientSecret() {
  const now = Math.floor(Date.now() / 1000);
  const head = b64url(JSON.stringify({ alg: "ES256", kid: ASA_KEY_ID }));
  const payload = b64url(JSON.stringify({
    sub: ASA_CLIENT_ID, iss: ASA_TEAM_ID, aud: "https://appleid.apple.com", iat: now, exp: now + 3600,
  }));
  const signer = crypto.createSign("SHA256");
  signer.update(`${head}.${payload}`);
  const sig = signer.sign({ key: fs.readFileSync(KEY_PATH, "utf8"), dsaEncoding: "ieee-p1363" });
  return `${head}.${payload}.${b64url(sig)}`;
}

let accessToken = null;
async function token() {
  if (accessToken) return accessToken;
  const res = await fetch("https://appleid.apple.com/auth/oauth2/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "client_credentials", client_id: ASA_CLIENT_ID, client_secret: clientSecret(), scope: "searchadsorg",
    }),
  });
  const json = await res.json().catch(() => null);
  if (!res.ok || !json?.access_token) fail(`token → HTTP ${res.status} ${JSON.stringify(json)}`);
  accessToken = json.access_token;
  return accessToken;
}

async function api(pathname, body = null, method = body ? "POST" : "GET") {
  const res = await fetch(`${API}${pathname}`, {
    method,
    headers: {
      Authorization: `Bearer ${await token()}`,
      "X-AP-Context": `adAccountId=${ASA_ORG_ID}`,
      ...(body ? { "Content-Type": "application/json" } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await res.json().catch(() => null);
  if (!res.ok) fail(`${method} ${pathname} → HTTP ${res.status} ${JSON.stringify(json?.error ?? json)}`);
  return json;
}

// Every list is a POST to a /query endpoint; pages until a short page comes back.
async function query(pathname, filters = [], pageSize = 1000) {
  const out = [];
  for (let offset = 0; ; offset += pageSize) {
    const page = (await api(pathname, { filters, pagination: { offset, pageSize } })).result ?? [];
    out.push(...page);
    if (page.length < pageSize) return out;
  }
}

const byCampaign = (id) => [{ field: "campaignId", operator: "EQUALS", value: id }];

// --- Reports ---------------------------------------------------------------

// Totals over the period (no granularity, so no daily rows): one request per
// level and campaign. Rows: { metadata, totalMetrics }.
async function report(level, from, to, filters = []) {
  const pageSize = 5000;
  const rows = [];
  for (let offset = 0; ; offset += pageSize) {
    const json = await api(`/reports/apps/${level}/query`, {
      timeRange: { start: from, end: to, timeZone: "ORTZ" },
      filters,
      pagination: { offset, pageSize },
    });
    const page = json.result?.rows ?? [];
    rows.push(...page);
    if (page.length < pageSize) return rows;
  }
}

const byName = (key) => (a, b) => String(a[key]).localeCompare(String(b[key]));

function metrics(t = {}) {
  const installs = t.totalInstalls ?? t.tapInstalls ?? t.installs ?? 0;
  const spend = Number(t.localSpend?.amount ?? 0);
  return {
    impressions: t.impressions ?? 0,
    taps: t.taps ?? 0,
    installs,
    spend: Math.round(spend * 100) / 100,
    cpi: installs ? Math.round((spend / installs) * 100) / 100 : null,
  };
}

function printTable(title, rows) {
  console.log(`\n## ${title}`);
  if (!rows.length) { console.log("(aucune ligne)"); return; }
  const cols = Object.keys(rows[0]);
  console.log(cols.join("\t"));
  for (const r of rows) console.log(cols.map((c) => r[c] ?? "—").join("\t"));
}

async function cmdAcls() {
  const json = await api("/acls");
  for (const { adAccount: a, roles } of json.result?.acls ?? []) {
    console.log(`${a.id}  ${a.name}  org ${a.orgId}  roles: ${(roles ?? []).join(", ")}`);
  }
}

async function cmdReport() {
  const from = args.from, to = args.to;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(from || "") || !/^\d{4}-\d{2}-\d{2}$/.test(to || "")) {
    fail("--from=YYYY-MM-DD and --to=YYYY-MM-DD are required");
  }
  const levels = new Set((typeof args.levels === "string" ? args.levels : "campaigns,adgroups,keywords,searchterms").split(","));
  const filter = typeof args.campaign === "string" ? args.campaign.toLowerCase() : null;
  const outDir = path.join(DATA_DIR, `${from}_${to}`);
  fs.mkdirSync(outDir, { recursive: true });
  const save = (name, json) => fs.writeFileSync(path.join(outDir, `${name}.json`), JSON.stringify(json, null, 2));

  const campaignRows = await report("campaigns", from, to);
  save("campaigns", campaignRows);
  const campaigns = campaignRows
    .map((r) => ({ id: r.metadata.id, name: r.metadata.name, status: r.metadata.displayStatus, ...metrics(r.totalMetrics) }))
    .filter((c) => !filter || c.name.toLowerCase().includes(filter))
    .sort(byName("name"));
  if (levels.has("campaigns")) printTable(`Campagnes ${from} → ${to}`, campaigns.map(({ id, ...c }) => c));

  for (const c of campaigns) {
    if (levels.has("adgroups")) {
      const rows = await report("adgroups", from, to, byCampaign(c.id));
      save(`adgroups-${c.id}`, rows);
      printTable(`Groupes — ${c.name}`, rows.map((r) => ({ adGroup: r.metadata.name, ...metrics(r.totalMetrics) })).sort(byName("adGroup")));
    }
    if (levels.has("keywords")) {
      const rows = await report("keywords", from, to, byCampaign(c.id));
      save(`keywords-${c.id}`, rows);
      printTable(`Mots-clés — ${c.name}`, rows.map((r) => ({
        keyword: r.metadata.text, match: r.metadata.matchType, adGroup: r.metadata.adGroup?.name,
        bid: r.metadata.bid?.amount, ...metrics(r.totalMetrics),
      })).sort(byName("keyword")));
    }
    if (levels.has("searchterms")) {
      const rows = await report("searchterms", from, to, byCampaign(c.id));
      save(`searchterms-${c.id}`, rows);
      printTable(`Termes de recherche — ${c.name}`, rows.map((r) => ({
        term: r.metadata.searchTermText ?? "(volume faible, masqué)", source: r.metadata.searchTermSource,
        keyword: r.metadata.keyword?.text, adGroup: r.metadata.adGroup?.name, ...metrics(r.totalMetrics),
      })).sort((a, b) => b.impressions - a.impressions));
    }
  }
  console.log(`\nJSON brut : ${path.relative(SCRIPT_DIR, outDir)}`);
}

// --- Bids ------------------------------------------------------------------

// Keywords from the management API, not the reports: a keyword with no
// impression yet still has a bid.
async function keywordsOf(campaignFilter) {
  const filter = typeof campaignFilter === "string" ? campaignFilter.toLowerCase() : null;
  const campaigns = (await query("/campaigns/query"))
    .filter((c) => !filter || c.name.toLowerCase().includes(filter))
    .sort(byName("name"));
  const out = [];
  for (const c of campaigns) {
    const groups = new Map((await query("/adgroups/query", byCampaign(c.id))).map((g) => [g.id, g]));
    for (const k of await query("/keywords/query", byCampaign(c.id))) {
      const g = groups.get(k.adGroupId);
      if (k.deleted || !g) continue;
      out.push({ campaign: c, adGroup: g, keyword: k });
    }
  }
  return out;
}

async function cmdBids() {
  const rows = await keywordsOf(args.campaign);
  printTable("Enchères", rows.map(({ campaign, adGroup, keyword }) => ({
    campaign: campaign.name, adGroup: adGroup.name, keyword: keyword.text, match: keyword.matchType,
    bid: keyword.bid?.amount, status: keyword.status,
  })));
}

async function cmdSetBid() {
  if (typeof args.campaign !== "string") fail("--campaign=<name part> is required");
  // Required so a brand group at a lower bid is never raised by accident.
  if (typeof args.adgroup !== "string") fail("--adgroup=<name part> is required");
  const adGroup = args.adgroup.toLowerCase();
  const bid = Number(args.bid);
  if (!(bid > 0 && bid < 10)) fail("--bid=<amount> is required, e.g. --bid=0.70");
  const match = typeof args.match === "string" ? args.match.toUpperCase() : "EXACT";
  const changes = (await keywordsOf(args.campaign))
    .filter(({ adGroup: g, keyword }) => g.name.toLowerCase().includes(adGroup)
      && keyword.matchType === match && Number(keyword.bid?.amount) !== bid);
  printTable(`${args.apply ? "Changement" : "Simulation"} : ${match} → ${bid.toFixed(2)}`,
    changes.map(({ campaign, keyword }) => ({
      campaign: campaign.name, keyword: keyword.text, from: keyword.bid?.amount, to: bid.toFixed(2),
    })));
  if (!args.apply || !changes.length) return;
  // All or nothing (no allowPartialSuccess): one bad item rejects the batch.
  const json = await api("/keywords/bulk-update", {
    items: changes.map(({ keyword }, i) => ({
      correlationId: i,
      data: { id: keyword.id, bid: { amount: bid.toFixed(2), currency: keyword.bid?.currency ?? "EUR" } },
    })),
  });
  const failed = (json.result ?? []).filter((r) => !r.success);
  if (failed.length) fail(`${failed.length} enchère(s) refusée(s) : ${JSON.stringify(failed)}`);
  console.log(`\n${changes.length} enchère(s) modifiée(s).`);
}

// --- Campaign status -------------------------------------------------------

async function cmdSetStatus() {
  if (typeof args.campaign !== "string") fail("--campaign=<name part> is required");
  const status = typeof args.status === "string" ? args.status.toUpperCase() : "";
  if (!["PAUSED", "ENABLED"].includes(status)) fail("--status=PAUSED or --status=ENABLED is required");
  const filter = args.campaign.toLowerCase();
  const matches = (await query("/campaigns/query")).filter((c) => !c.deleted && c.name.toLowerCase().includes(filter));
  // One campaign at a time: a loose filter must never pause several.
  if (matches.length !== 1) fail(`--campaign matches ${matches.length} campaigns: ${matches.map((c) => c.name).join(", ") || "none"}`);
  const [c] = matches;
  console.log(`${c.name} : ${c.status} → ${status}${args.apply ? "" : " (simulation, --apply pour écrire)"}`);
  if (!args.apply || c.status === status) return;
  // Campaigns have no bulk endpoint; PUT changes only the fields sent.
  const { result } = await api(`/campaigns/${c.id}`, { status }, "PUT");
  console.log(`Fait : ${result?.status}`);
}

const COMMANDS = { acls: cmdAcls, report: cmdReport, bids: cmdBids, "set-bid": cmdSetBid, "set-status": cmdSetStatus };
if (!COMMANDS[command]) fail(`unknown command "${command}" (${Object.keys(COMMANDS).join(", ")})`);
await COMMANDS[command]();
