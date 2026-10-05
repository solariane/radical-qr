#!/usr/bin/env node
/**
 * appleads-stats.mjs
 *
 * Reads Apple Ads (Search Ads) reports through the Campaign Management API v5,
 * with a read-only API user. Prints campaign, ad group, keyword and search-term
 * totals for a period and saves the raw JSON in marketing/stats/data/appleads/.
 *
 * Auth: a client secret (JWT, ES256) signed with ../appleads_private_key.pem is
 * exchanged at appleid.apple.com for a one-hour access token.
 *
 * Credentials (environment or ../.env):
 *   ASA_CLIENT_ID, ASA_TEAM_ID, ASA_KEY_ID  — shown in Apple Ads → Account Settings → API
 *   ASA_KEY_PATH                           — the EC P-256 private key whose public half is uploaded there
 *   ASA_ORG_ID                             — the account's org id
 *
 * Usage:
 *   node appleads-stats.mjs acls                              # check access, list orgs
 *   node appleads-stats.mjs report --from=2026-10-05 --to=2026-10-11
 *        [--levels=campaigns,adgroups,keywords,searchterms] [--campaign=<name part>]
 */

import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const DATA_DIR = path.join(SCRIPT_DIR, "marketing", "stats", "data", "appleads");
const API = "https://api.searchads.apple.com/api/v5";

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

async function api(pathname, body = null) {
  const res = await fetch(`${API}${pathname}`, {
    method: body ? "POST" : "GET",
    headers: {
      Authorization: `Bearer ${await token()}`,
      "X-AP-Context": `orgId=${ASA_ORG_ID}`,
      ...(body ? { "Content-Type": "application/json" } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await res.json().catch(() => null);
  if (!res.ok) fail(`${body ? "POST" : "GET"} ${pathname} → HTTP ${res.status} ${JSON.stringify(json?.error ?? json)}`);
  return json;
}

// --- Reports ---------------------------------------------------------------

// Totals over the period (no daily rows): one request per level and campaign.
function reportBody(from, to, orderBy) {
  return {
    startTime: from,
    endTime: to,
    selector: { orderBy: [{ field: orderBy, sortOrder: "ASCENDING" }], pagination: { offset: 0, limit: 1000 } },
    timeZone: "ORTZ",
    returnRecordsWithNoMetrics: false,
    returnRowTotals: true,
    returnGrandTotals: true,
  };
}

const rowsOf = (json) => json?.data?.reportingDataResponse?.row ?? [];

// v5 renamed installs (tapInstalls / totalInstalls); read whichever is there.
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
  for (const o of json.data ?? []) {
    console.log(`${o.orgId}  ${o.orgName}  ${o.currency}  ${o.paymentModel}  roles: ${(o.roleNames ?? []).join(", ")}`);
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

  const campaignsJson = await api("/reports/campaigns", reportBody(from, to, "campaignName"));
  save("campaigns", campaignsJson);
  const campaigns = rowsOf(campaignsJson)
    .map((r) => ({ id: r.metadata.campaignId, name: r.metadata.campaignName, status: r.metadata.displayStatus, ...metrics(r.total) }))
    .filter((c) => !filter || c.name.toLowerCase().includes(filter));
  if (levels.has("campaigns")) printTable(`Campagnes ${from} → ${to}`, campaigns.map(({ id, ...c }) => c));

  for (const c of campaigns) {
    if (levels.has("adgroups")) {
      const json = await api(`/reports/campaigns/${c.id}/adgroups`, reportBody(from, to, "adGroupName"));
      save(`adgroups-${c.id}`, json);
      printTable(`Groupes — ${c.name}`, rowsOf(json).map((r) => ({ adGroup: r.metadata.adGroupName, ...metrics(r.total) })));
    }
    if (levels.has("keywords")) {
      const json = await api(`/reports/campaigns/${c.id}/keywords`, reportBody(from, to, "keyword"));
      save(`keywords-${c.id}`, json);
      printTable(`Mots-clés — ${c.name}`, rowsOf(json).map((r) => ({
        keyword: r.metadata.keyword, match: r.metadata.matchType, adGroup: r.metadata.adGroupName,
        bid: r.metadata.bidAmount?.amount, ...metrics(r.total),
      })));
    }
    if (levels.has("searchterms")) {
      const json = await api(`/reports/campaigns/${c.id}/searchterms`, reportBody(from, to, "impressions"));
      save(`searchterms-${c.id}`, json);
      printTable(`Termes de recherche — ${c.name}`, rowsOf(json).map((r) => ({
        term: r.metadata.searchTermText ?? "(volume faible, masqué)", source: r.metadata.searchTermSource,
        keyword: r.metadata.keyword, adGroup: r.metadata.adGroupName, ...metrics(r.total),
      })));
    }
  }
  console.log(`\nJSON brut : ${path.relative(SCRIPT_DIR, outDir)}`);
}

const COMMANDS = { acls: cmdAcls, report: cmdReport };
if (!COMMANDS[command]) fail(`unknown command "${command}" (${Object.keys(COMMANDS).join(", ")})`);
await COMMANDS[command]();
