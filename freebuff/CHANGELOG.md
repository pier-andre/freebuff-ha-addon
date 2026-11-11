# Journal des modifications

Ce fichier est complété automatiquement par Renovate : chaque pull request de mise à jour ajoute une
ligne dans « Non publié » et incrémente simultanément le `version:` de `config.yaml`.

## Non publié

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
