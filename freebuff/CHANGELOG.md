# Journal des modifications

Ce fichier est complété automatiquement par Renovate : chaque pull request de mise à jour ajoute une
ligne dans « Non publié » et incrémente simultanément le `version:` de `config.yaml`.

## Non publié

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
