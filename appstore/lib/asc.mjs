/**
 * asc.mjs — shared App Store Connect API client for the App Store pipeline.
 *
 * Apple caps a JWT at 20 minutes, and a full screenshot upload runs longer, so
 * the token is signed lazily and re-signed once it is 15 minutes old. A 401 is
 * retried once with a fresh token: Apple rejected the request before acting on
 * it, so this is safe for writes too.
 *
 * A GET is also retried on HTTP 5xx and on network errors, with exponential
 * backoff (a transient 500 while polling `assetDeliveryState` used to abort a
 * whole run). Writes are not retried on 5xx: the server may have applied them.
 */

import fs from "node:fs";
import crypto from "node:crypto";

export const ASC_API = "https://api.appstoreconnect.apple.com";

const TOKEN_LIFETIME_S = 20 * 60; // Apple's maximum
const TOKEN_REFRESH_S = 15 * 60;

const b64url = (buf) =>
  Buffer.from(buf).toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * @param {object} o
 * @param {string} o.issuerId
 * @param {string} o.keyId
 * @param {string} o.keyPath          path to the AuthKey_XXXX.p8
 * @param {(message: string) => never} o.fail   called with the error text on a non-retryable failure
 * @param {(r: {method, pathname, reason, attempt, attempts, delayMs}) => void} [o.onRetry]
 * @param {number} [o.attempts=4]     total tries for a GET on 5xx / network error
 * @param {boolean} [o.retryWritesOnNetworkError=false]  also retry non-GET requests
 *        when fetch itself throws (the request may or may not have reached Apple)
 * @returns {(pathname: string, opts?: {method?, body?, tolerate?: number[]}) => Promise<any>}
 */
export function createAscClient({
  issuerId, keyId, keyPath, fail, onRetry = () => {}, attempts = 4, retryWritesOnNetworkError = false,
}) {
  let token = null;
  let signedAt = 0;

  function signJWT() {
    const now = Math.floor(Date.now() / 1000);
    const head = b64url(JSON.stringify({ alg: "ES256", kid: keyId, typ: "JWT" }));
    const payload = b64url(JSON.stringify({ iss: issuerId, iat: now, exp: now + TOKEN_LIFETIME_S, aud: "appstoreconnect-v1" }));
    const signer = crypto.createSign("SHA256");
    signer.update(`${head}.${payload}`);
    signer.end();
    signedAt = now;
    return `${head}.${payload}.${b64url(signer.sign({ key: fs.readFileSync(keyPath, "utf8"), dsaEncoding: "ieee-p1363" }))}`;
  }

  function currentToken({ forceRefresh = false } = {}) {
    const age = Math.floor(Date.now() / 1000) - signedAt;
    if (forceRefresh || !token || age >= TOKEN_REFRESH_S) token = signJWT();
    return token;
  }

  return async function asc(pathname, { method = "GET", body = null, tolerate = [] } = {}) {
    const url = pathname.startsWith("http") ? pathname : `${ASC_API}${pathname}`;
    const reqBody = body ? JSON.stringify(body) : null;
    const retryable = method === "GET";
    const maxAttempts = retryable ? attempts : 1;
    let refreshedAfter401 = false;

    for (let attempt = 1; ; attempt += 1) {
      const headers = { Authorization: `Bearer ${currentToken()}` };
      if (reqBody) headers["Content-Type"] = "application/json";

      let res;
      try {
        res = await fetch(url, { method, headers, body: reqBody });
      } catch (e) {
        if (!(retryable || retryWritesOnNetworkError) || attempt >= attempts) throw e;
        const delayMs = 1000 * 2 ** (attempt - 1);
        onRetry({ method, pathname, reason: e.cause?.code || e.message, attempt, attempts, delayMs });
        await sleep(delayMs);
        continue;
      }

      if (res.status === 401 && !refreshedAfter401) {
        await res.body?.cancel();
        refreshedAfter401 = true;
        currentToken({ forceRefresh: true });
        onRetry({ method, pathname, reason: "HTTP 401", attempt, attempts: maxAttempts, delayMs: 0 });
        attempt -= 1; // a token refresh does not count against the 5xx budget
        continue;
      }

      if (res.status >= 500 && retryable && attempt < maxAttempts) {
        await res.body?.cancel();
        const delayMs = 2000 * 2 ** (attempt - 1);
        onRetry({ method, pathname, reason: `HTTP ${res.status}`, attempt, attempts: maxAttempts, delayMs });
        await sleep(delayMs);
        continue;
      }

      const text = await res.text();
      let json = null;
      try { json = text ? JSON.parse(text) : null; } catch { /* empty body */ }
      if (!res.ok) {
        if (tolerate.includes(res.status)) return { __error: res.status, json };
        const err = json?.errors?.[0];
        fail(`ASC ${method} ${pathname} → HTTP ${res.status}${err ? `\n  ${err.title}: ${err.detail}` : `\n  ${text}`}`);
      }
      return json;
    }
  };
}
