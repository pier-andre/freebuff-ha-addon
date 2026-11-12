# Journal des modifications

Ce fichier est complété automatiquement par Renovate : chaque pull request de mise à jour ajoute une
ligne dans « Non publié » et incrémente simultanément le `version:` de `config.yaml`.

## Non publié

## 0.2.7
- 2026-11-12 — API Freebuff2API : les modèles proviennent désormais de `GET /api/v1/freebuff/models`, la même source que la commande `/model` de la CLI, au lieu du scraping de `free-agents.ts`.
  - Le scraping ne reconnaissait plus que `google/gemini-2.5-flash-lite`, un modèle retiré de Freebuff : l'API n'exposait donc qu'un modèle inutilisable.
  - `/v1/models` renvoie les noms réels du catalogue (par exemple « DeepSeek V4.1 Flash Fast ») ; le proxy envoie le handle de compte correspondant et les en-têtes du protocole catalogue, et rafraîchit la liste avant expiration des handles.
  - Une session free invalide reconstruit maintenant le run associé : elle était rejouée avec le même `run_id`, mort avec l'ancienne session, ce qui produisait `502 upstream run expired twice in a row`.

## 0.2.6
- 2026-11-12 — `nodejs/node` 22.23.4 → 26.13.0 (mise à jour majeure)
  - Node.js 25 et suivants lient leurs binaires Linux à `libatomic` : l'image installe désormais `libatomic1`, sans quoi `node` ne démarre pas.

## 0.2.5
- 2026-11-12 — `nodejs/node` 22.11.0 → 22.23.4 (mise à jour mineure)

## 0.2.4
- fix installation initiale github avec chemin manquant bloquant la première exécution

## 0.2.3

- Le panneau est désormais réservé aux comptes administrateurs (`panel_admin: true`). Le terminal
  donne un accès root au dossier de configuration de Home Assistant ; il n'a pas à être ouvert aux
  autres comptes de l'instance. Reconstruction nécessaire pour que le réglage prenne effet.

## 0.2.2

- Icône du panneau remplacée : `mdi:console-line` (une invite de terminal) au lieu de
  `mdi:robot-happy-outline`, pour que l'icône de la barre latérale dise ce que fait l'add-on.

## 0.2.1

- L'add-on vit maintenant dans le dossier `freebuff/` du dépôt, à côté de son `CHANGELOG.md` : c'est
  la disposition attendue par la boutique Home Assistant et par le modèle `renovate.json` du dépôt.
- Correction de l'ordre d'initialisation : `export HOME=/data/freebuff` s'exécute désormais avant
  `git config`, donc l'identité Git et l'aide d'authentification du jeton GitHub sont écrites dans
  `/data` et survivent aux redémarrages de l'add-on.
- Ajout de `renovate.json` à la racine du dépôt : mises à jour de Node.js et de ttyd, incrément de
  version et ligne de journal automatiques.

## 0.2.0

- Nouvelle option `github_token` : jeton GitHub utilisé par `git` pour les `push` et `pull` sans
  saisie manuelle, y compris pour l'agent.
- URL du dépôt corrigée dans `config.yaml`, `repository.yaml` et `DOCS.md`.

## 0.1.0

- Version initiale : terminal web (ttyd + tmux), CLI Freebuff et proxy Freebuff2API optionnel.
