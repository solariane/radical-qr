/**
 * asset-library.mjs — captures iPhone Duo via l'« App Asset Library ».
 *
 * L'API classique (appScreenshotSets / screenshotDisplayType) n'a pas de type
 * pour l'iPhone Duo : Apple le fait passer par la bibliothèque d'assets de
 * l'app (API 4.5). Le chemin est différent :
 *
 *   1. GET  /v1/apps/{id}/assetLibrary            → id de la bibliothèque
 *   2. POST /v1/appAssetLibraryImages             → réserve l'image, renvoie
 *                                                    des `uploadOperations`
 *   3. PUT  sur chaque opération                  → les octets
 *   4. PATCH /v1/appAssetLibraryImages/{id}       → uploaded:true
 *      puis on attend que `state` quitte AWAITING_UPLOAD / UPLOAD_COMPLETE
 *   5. POST /v1/appAssetLibraryPlacements         → pose l'image sur la
 *      localisation de la version, groupe IPHONE_DUO_PROFILE
 *   6. POST /v1/appAssetLibraryPlacementOrderingRequests → ordre d'affichage
 *
 * Le groupe IPHONE_DUO_PROFILE (lu dans /v1/appAssetLibraryRefData le
 * 08/10/2026) accepte 10 images au plus, sans transparence, à l'une des tailles
 * 1398×2034 / 2034×1398 (écran extérieur) ou 2007×2853 / 2853×2007 (intérieur).
 *
 * Remplacer un jeu = supprimer les placements de la localisation, puis archiver
 * les images qui ne sont plus placées nulle part, pour que la bibliothèque ne
 * grossisse pas à chaque envoi.
 *
 * Même fichier dans cleanUpPhoneNumbers, Radical QR et TUV iOS.
 */

import fs from "node:fs";
import path from "node:path";

export const DUO_GROUP = "IPHONE_DUO_PROFILE";
export const DUO_MAX = 10;

const PENDING = new Set(["AWAITING_UPLOAD", "UPLOAD_COMPLETE"]);

/**
 * @param {object} o
 * @param {Function} o.asc          client ASC : asc(pathname, {method, body, tolerate})
 * @param {Function} o.fetchRetry   fetch avec reprise, pour les PUT d'octets
 * @param {string}   o.appId
 * @returns {Promise<string|null>}  id de la bibliothèque, null si le compte n'y a pas accès
 */
export async function assetLibraryId({ asc, appId }) {
  const res = await asc(`/v1/apps/${appId}/assetLibrary`, { tolerate: [403, 404] });
  if (res?.__error) return null;
  return res?.data?.id ?? null;
}

/** Placements Duo d'une localisation, dans l'ordre où ASC les rend. */
export async function duoPlacements({ asc, locId }) {
  const res = await asc(
    `/v1/appStoreVersionLocalizations/${locId}/placements` +
      `?filter[placementType]=APP_SCREENSHOT&filter[placementGroup]=${DUO_GROUP}&include=image&limit=50`
  );
  return (res?.data ?? []).map((p) => ({
    id: p.id,
    imageId: p.relationships?.image?.data?.id ?? null,
    state: p.attributes?.state,
  }));
}

/** Supprime les placements Duo d'une localisation et archive les images devenues orphelines. */
export async function clearDuoPlacements({ asc, locId }) {
  const placements = await duoPlacements({ asc, locId });
  for (const p of placements) {
    await asc(`/v1/appAssetLibraryPlacements/${p.id}`, { method: "DELETE" });
  }
  for (const imageId of new Set(placements.map((p) => p.imageId).filter(Boolean))) {
    const still = await asc(`/v1/appAssetLibraryImages/${imageId}/placements?limit=1`);
    if ((still?.data ?? []).length) continue;
    await asc(`/v1/appAssetLibraryImages/${imageId}`, {
      method: "PATCH",
      body: { data: { type: "appAssetLibraryImages", id: imageId, attributes: { archived: true } } },
    });
  }
  return placements.length;
}

/** Envoie une image dans la bibliothèque et attend qu'Apple l'ait traitée. */
export async function uploadLibraryImage({ asc, fetchRetry, libraryId, filePath }) {
  const buffer = fs.readFileSync(filePath);
  const fileName = path.basename(filePath);

  const reservation = await asc("/v1/appAssetLibraryImages", {
    method: "POST",
    body: {
      data: {
        type: "appAssetLibraryImages",
        attributes: {
          category: "APP_SCREENSHOTS_AND_PREVIEWS",
          fileName,
          fileSize: buffer.length,
          referenceName: fileName.replace(/\.png$/, ""),
        },
        relationships: { assetLibrary: { data: { type: "appAssetLibraries", id: libraryId } } },
      },
    },
  });

  const id = reservation.data.id;
  for (const op of reservation.data.attributes?.uploadOperations ?? []) {
    const headers = {};
    for (const h of op.requestHeaders ?? []) headers[h.name] = h.value;
    const res = await fetchRetry(op.url, {
      method: op.method,
      headers,
      body: buffer.subarray(op.offset, op.offset + op.length),
    });
    if (!res.ok) return { id, state: "FAILED", errors: `HTTP ${res.status} sur ${op.url}` };
  }

  await asc(`/v1/appAssetLibraryImages/${id}`, {
    method: "PATCH",
    body: { data: { type: "appAssetLibraryImages", id, attributes: { uploaded: true } } },
  });

  for (let attempt = 0; attempt < 60; attempt += 1) {
    const res = await asc(`/v1/appAssetLibraryImages/${id}`);
    const attrs = res?.data?.attributes ?? {};
    if (attrs.state === "FAILED") {
      const errors = (attrs.stateDetails ?? []).map((e) => `${e.code ?? ""} ${e.description ?? e.message ?? ""}`.trim()).join("; ");
      return { id, state: "FAILED", errors };
    }
    if (attrs.state && !PENDING.has(attrs.state)) return { id, state: attrs.state };
    await new Promise((r) => setTimeout(r, 2000));
  }
  return { id, state: "TIMEOUT" };
}

/** Pose une image de la bibliothèque comme capture Duo d'une localisation. */
export async function placeDuoScreenshot({ asc, imageId, locId }) {
  const res = await asc("/v1/appAssetLibraryPlacements", {
    method: "POST",
    body: {
      data: {
        type: "appAssetLibraryPlacements",
        attributes: { placementType: "APP_SCREENSHOT", placementGroup: DUO_GROUP },
        relationships: {
          image: { data: { type: "appAssetLibraryImages", id: imageId } },
          appStoreVersionLocalization: { data: { type: "appStoreVersionLocalizations", id: locId } },
        },
      },
    },
  });
  return res.data.id;
}

/** Fixe l'ordre des captures Duo d'une localisation. */
export async function orderDuoPlacements({ asc, locId, placementIds }) {
  if (placementIds.length < 2) return;
  await asc("/v1/appAssetLibraryPlacementOrderingRequests", {
    method: "POST",
    body: {
      data: {
        type: "appAssetLibraryPlacementOrderingRequests",
        attributes: { placementGroup: DUO_GROUP },
        relationships: {
          orderedPlacements: { data: placementIds.map((id) => ({ type: "appAssetLibraryPlacements", id })) },
          appStoreVersionLocalization: { data: { type: "appStoreVersionLocalizations", id: locId } },
        },
      },
    },
  });
}
