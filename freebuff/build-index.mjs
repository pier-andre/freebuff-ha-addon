// Insère le fragment mobile.html dans la page servie par ttyd, au build.
// La page de ttyd 1.7.7 est autonome (xterm.js est inliné) : on récupère donc la
// page exacte de la version compilée, on ajoute le fragment avant </head>, et on
// écrit le résultat. Rien n'est copié de ttyd dans le dépôt, et une mise à jour
// de ttyd régénère la page au build suivant.
import { readFileSync, writeFileSync } from "node:fs";

const [pagePath, patchPath, outPath] = process.argv.slice(2);
if (!pagePath || !patchPath || !outPath) {
  console.error("usage: build-index.mjs <page ttyd> <fragment> <sortie>");
  process.exit(2);
}

const marker = "freebuff-mobile";
const page = readFileSync(pagePath, "utf8");
const patch = readFileSync(patchPath, "utf8");

if (!page.includes("</head>")) {
  throw new Error(`page ttyd inattendue (pas de </head>) : ${pagePath}`);
}
if (page.includes(marker)) {
  throw new Error("page ttyd déjà personnalisée : mise à jour de ttyd incomplète ?");
}
if (!patch.includes(marker)) {
  throw new Error(`fragment sans marqueur ${marker} : ${patchPath}`);
}

const out = page.replace("</head>", `${patch}</head>`);
if (out.length <= page.length || !out.includes(marker)) {
  throw new Error("insertion du correctif échouée");
}

writeFileSync(outPath, out);
console.log(`page ttyd personnalisée : ${outPath} (${out.length} octets)`);
