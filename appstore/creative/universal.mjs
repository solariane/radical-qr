/**
 * universal.mjs — « Universal Creative Asset » de l'App Store (iOS 27+),
 * 5244 × 2950 (16:9). Un seul visuel, recadré par l'App Store pour l'en-tête
 * de la fiche (2,33:1, bandeau) et pour les résultats de recherche (3:2).
 * Même dispositif que cleanUpPhoneNumbers/appstore/creative/.
 *
 * Aucun texte : le visuel sert les 10 fiches tel quel, et Apple n'y veut ni
 * prix ni promesse. Variante « styles » : l'app en trois temps, de gauche à
 * droite — cinq contenus reconnus → un QR code élégant, avec le logo au
 * centre → trois styles différents. La variante « privacy » est dans
 * universal-privacy.mjs, la combinaison des deux dans universal-shield.mjs ;
 * ce qu'elles partagent est dans lib.mjs.
 *
 *   node universal.mjs   →  out/universal.svg
 *   ./render.sh          →  out/universal.jpg (+ aperçus des deux recadrages)
 */

import { cx, inputColumn, qrCard, styleTiles, writeSvg } from "./lib.mjs";

const card = 1500;
const inputs = inputColumn({ x: cx - 1360, lineEnd: cx - card / 2 - 70 });
const centre = qrCard({ card });

const tiles = styleTiles();

writeSvg("universal", inputs.defs + centre.defs, inputs.body + tiles + centre.body);
