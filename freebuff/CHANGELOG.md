# Journal des modifications

Ce fichier est complété automatiquement par Renovate : chaque pull request de mise à jour ajoute une
ligne dans « Non publié » et incrémente simultanément le `version:` de `config.yaml`.

## Non publié

## 0.2.12
- 2026-11-13 — Correction du fichier MCP : `/local_apps/.agents/mcp.json` suit désormais les
  options. Il était écrit une seule fois puis considéré comme « personnalisé », si bien qu'un
  changement de `mcp_url` laissait la CLI brancher l'ancienne adresse.
- Le fichier n'est réécrit que s'il a été écrit par l'add-on : empreinte conservée dans
  `/data/mcp-managed.json`, plus reprise en main des fichiers des versions précédentes
  (forme reconnaissable), avec sauvegarde dans `/data/mcp-backups` avant toute réécriture.
  Un fichier modifié à la main reste intact et le journal indique l'adresse réellement utilisée.
- `mcp_url` sans port explicite mais sur l'hôte de Home Assistant (`http://homeassistant.local/api/mcp_http`)
  reçoit `home_assistant_port` au lieu de partir sur le port 80 ; le journal le signale.
- Même instance MCP que Home Assistant : le jeton longue durée est réutilisé automatiquement pour
  `/api/mcp_http`, sans renseigner `mcp_token` ni exposer le jeton à un autre conteneur (comparaison
  de l'origine, schéma et port compris).
- Échec de connexion journalisé avec sa cause (`HTTP 401`, délai dépassé, injoignable) et rappel de
  l'adresse encore inscrite dans le fichier.
- Documentation : fichier géré, autorisation `.agents/` au premier lancement.

## 0.2.11
- 2026-11-13 — Téléphone et tablette : la page servie par ttyd reçoit au build un fragment
  (`mobile.html`, inséré par `build-index.mjs`) qui ajoute la balise `viewport` manquante, le
  défilement de la conversation au doigt (glissement traduit en crans de molette, avec inertie) et un
  champ de saisie compatible avec les claviers à prédiction — sans modifier ttyd ni xterm.js.
- `tmux.conf` : `mouse on` (molette et défilement tactile entrent en mode copie) et historique de
  50 000 lignes, pour remonter une longue conversation de l'agent.
- Le champ de saisie caché de xterm est ramené dans la page et fixé à 16 px : iOS y plaçait mal le
  curseur d'IME puisqu'il était déporté hors écran, et un champ plus petit déclenchait le zoom
  automatique de Safari.
- Soupape de sûreté : si la page ne peut pas être personnalisée, l'add-on sert l'interface d'origine
  de ttyd et le signale au démarrage au lieu de refuser de démarrer.

## 0.2.10
- 2026-11-13 — Outils MCP facultatifs : au démarrage, l'add-on écrit
  `/local_apps/.agents/mcp.json` (format `mcpServers`, transport `http`) pour que la CLI Freebuff
  dispose des outils MCP de Home Assistant — tableaux de bord, fichiers YAML avec sauvegarde,
  `check_config`, traces, statistiques — en plus de l'API REST.
- Un seul fichier couvre les montages courants : intégration intégrée `mcp_server` et composants
  exposant `/api/mcp` (adresse dérivée de `HA_URL`, jeton longue durée), app HA-MCP du Marketplace
  (port 9583, chemin secret, sans jeton) et serveurs `hass-mcp` / `ha-mcp-web` via `mcp_url`.
- Nouvelles options `mcp_url` et `mcp_token`. Aucun secret n'est écrit dans le fichier : l'en-tête
  contient `Bearer $HOME_ASSISTANT_TOKEN` ou `Bearer $MCP_TOKEN`, résolu par la CLI.
- Le fichier n'est écrit que si le serveur répond à une poignée de main MCP, et reste intact s'il a
  été personnalisé. Sinon un avertissement s'affiche et l'API REST prend le relais.
- Sans jeton longue durée, MCP est ignoré : le proxy Supervisor ne relaie pas `/api/mcp`
  (502 constaté), ce qui n'affecte pas les routes REST.
- `AGENTS.md` : section MCP (sauvegarde avant écriture, `check_config` après, jamais de redémarrage
  ni de suppression via les outils MCP).

## 0.2.9
- 2026-11-13 — Retrait des derniers restes de l'API tierce : `patches/` (correctif Freebuff2API et
  son mode d'emploi) est supprimé, plus aucun fichier de l'add-on ne s'y réfère.
- L'accès à l'API Home Assistant est configurable : nouvelles options `home_assistant_url` et
  `home_assistant_port` (défaut `http://homeassistant:8123`), pour une instance derrière un reverse
  proxy ou en HTTPS. `home_assistant_token` reste un champ secret, jamais écrit sur le disque.
- Sans jeton longue durée configuré, `HA_URL`/`HA_TOKEN` pointent vers le proxy Supervisor
  (`http://supervisor/core`, permission `homeassistant_api`) pour que la validation de configuration
  fonctionne dès l'installation.
- Ajout de `AGENTS.md` : contexte et garde-fous remis à l'agent (changements non destructifs,
  sauvegarde préalable, validation `check_config` obligatoire et restauration en cas d'échec).

## 0.2.8
- 2026-11-13 — Retrait de l'API tierce optionnelle et de ses sources et options associées.
- Ajout d'une option secrète pour injecter un jeton Home Assistant longue durée dans l'environnement du terminal.

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

- Version initiale : terminal web (ttyd + tmux) et CLI Freebuff.
