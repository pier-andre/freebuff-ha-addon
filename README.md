# Freebuff pour Home Assistant

Un add-on qui fournit la CLI [Freebuff](https://freebuff.com/cli) dans un terminal web intégré à Home Assistant,
et peut aussi exposer un proxy API compatible OpenAI sur le réseau local.

## Ce que fait l'add-on

- installe Node.js + `freebuff` (CLI officielle, toujours la dernière version au moment du build) ;
- ouvre un terminal web (ttyd + tmux) intégré à Home Assistant via Ingress ;
- monte `/local_apps` (vos add-ons locaux) et `/homeassistant` (votre configuration HA) ;
- garde la session Freebuff dans `/data`, donc vous ne vous reconnectez pas après un redémarrage.
- peut démarrer [Freebuff2API](https://github.com/Quorinex/Freebuff2API) sur le port TCP 11436 pour les clients locaux.

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

3. Home Assistant installe l'add-on sous le nom `<empreinte>_freebuff` (l'empreinte vient de l'URL du
   dépôt), donc ses données vivent dans `/data/apps/data/<empreinte>_freebuff`. Si vous passez d'une
   copie locale installée depuis `/addons`, déplacez ce dossier avant de démarrer la nouvelle
   installation, sinon vous repartez d'un `/data` vide (historique de conversations et configuration
   Git compris).

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

### API compatible OpenAI sur le réseau local

Dans les options de l'add-on, activez `api_enabled` et définissez `api_keys`. Le proxy réutilise le jeton
de la session CLI, stocké dans `/data/freebuff/.config/manicode/credentials.json`. Connectez-vous avec
`freebuff login` avant d'activer l'API; si vous vous connectez après son démarrage, redémarrez l'add-on.
L'API est disponible sur `http://ADRESSE_IP_DE_HOME_ASSISTANT:11436/v1`. Le client doit utiliser la clé
définie dans `api_keys`. L'API est désactivée par défaut et ne démarre pas sans clé client. N'exposez pas
le port 11436 à Internet.

## Limites connues

- La CLI Freebuff est interactive et nécessite le terminal web. Pour les clients OpenAI compatibles,
  activez plutôt le proxy Freebuff2API dans les options de l'add-on.
- Dépend de l'architecture : `amd64` fonctionne ; `aarch64` (Raspberry Pi, HA Green/Yellow)
  dépend de l'existence d'un binaire Linux ARM côté Freebuff. Si le build échoue sur ARM,
  retirez `aarch64` de la liste `arch` dans `config.yaml`.
- Freebuff est financé par des bandeaux publicitaires affichés dans la CLI.
- Cet add-on n'est pas maintenu par Home Assistant ni par Freebuff : c'est un emballage communautaire.
