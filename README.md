# Freebuff pour Home Assistant

Un add-on qui fournit la CLI [Freebuff](https://freebuff.com/cli) dans un terminal web intégré à Home Assistant,
et peut recevoir un jeton dédié pour accéder à l'API locale de Home Assistant.

[![Ouvrir votre instance Home Assistant et afficher le dialogue d’ajout du dépôt avec l’URL pré-remplie.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fpier-andre%2Ffreebuff-ha-addon) [![Ouvrir votre instance Home Assistant et afficher la page de l’add-on Freebuff.](https://my.home-assistant.io/badges/supervisor_app.svg)](https://my.home-assistant.io/redirect/supervisor_app/?app=dc337d8e_freebuff&repository_url=https%3A%2F%2Fgithub.com%2Fpier-andre%2Ffreebuff-ha-addon)

## Ce que fait l'add-on

- installe Node.js + `freebuff` (CLI officielle, toujours la dernière version au moment du build) ;
- ouvre un terminal web (ttyd + tmux) intégré à Home Assistant via Ingress ;
- monte `/local_apps` (vos add-ons locaux) et `/homeassistant` (votre configuration HA) ;
- garde la session Freebuff dans `/data`, donc vous ne vous reconnectez pas après un redémarrage.
- peut recevoir un jeton Home Assistant local dans son environnement pour accéder à l'API Home Assistant.

## Installation

L'add-on vit dans le dossier `freebuff/` de ce dépôt, et son nom est son identifiant :
`freebuff/config.yaml`, `freebuff/Dockerfile`, `freebuff/run.sh`, `freebuff/DOCS.md` et
`freebuff/CHANGELOG.md` doivent rester ensemble. `repository.yaml` et `renovate.json` restent à la
racine du dépôt.

1. Dans Home Assistant : **Paramètres → Modules complémentaires → Boutique des modules complémentaires**
   → menu ⋮ → **Dépôts** → collez `https://github.com/pier-andre/freebuff-ha-addon` → **Ajouter**.
   Le dépôt doit rester **public** : la boutique clone sans identifiants.

2. L'add-on « Freebuff CLI » apparaît dans la boutique. **Installer**, puis **Démarrer**.
   (Comptez plusieurs minutes pour la première installation : Node.js + Freebuff sont téléchargés.)

3. Home Assistant installe l'add-on sous le nom `dc337d8e_freebuff` : le préfixe `dc337d8e` est le
   début du SHA-1 de l'URL du dépôt, calculé sur l'URL telle que saisie (sans `/` final ni `.git`,
   sinon le préfixe change). Ses données vivent donc dans `/data/apps/data/dc337d8e_freebuff`. Si vous
   passez d'une copie locale installée depuis `/addons` (identifiant `local_freebuff`), déplacez
   `/data/apps/data/local_freebuff` vers `/data/apps/data/dc337d8e_freebuff` avant de démarrer la
   nouvelle installation, sinon vous repartez d'un `/data` vide (historique de conversations et
   configuration Git compris).

### Mises à jour

Le fichier `renovate.json` à la racine du dépôt est lu par l'add-on
[Renovate](https://github.com/pier-andre/renovate-ha-addon) : une mise à jour de dépendance arrive en
pull request avec le `version:` de `freebuff/config.yaml` incrémenté et une ligne ajoutée dans
`freebuff/CHANGELOG.md`. Après fusion, la boutique la propose au prochain « Vérifier les mises à jour ».

5. Ouvrez **Freebuff** dans la barre latérale, puis tapez `freebuff login` et suivez le lien affiché
   sur votre téléphone ou votre ordinateur. Revenez dans le terminal : c'est connecté.

## Utilisation

```bash
cd /local_apps/mon-add-on     # un add-on en cours de développement
freebuff                      # l'agent démarre
```

Pour un dépôt GitHub classique, clonez-le dans `/share` (ou `/local_apps`) et lancez `freebuff` dedans.

### Accès à Home Assistant

Vous pouvez enregistrer un jeton longue durée d'un compte Home Assistant dédié dans l'option secrète
`home_assistant_token`. Le terminal le reçoit dans `HOME_ASSISTANT_TOKEN` et `HA_TOKEN`, avec l'adresse
locale `HA_URL=http://homeassistant:8123`. Limitez les permissions du compte au strict nécessaire.

## Limites connues

- La CLI Freebuff est interactive et nécessite le terminal web.
- Dépend de l'architecture : `amd64` fonctionne ; `aarch64` (Raspberry Pi, HA Green/Yellow)
  dépend de l'existence d'un binaire Linux ARM côté Freebuff. Si le build échoue sur ARM,
  retirez `aarch64` de la liste `arch` dans `config.yaml`.
- Freebuff est financé par des bandeaux publicitaires affichés dans la CLI.
- Cet add-on n'est pas maintenu par Home Assistant ni par Freebuff : c'est un emballage communautaire.
