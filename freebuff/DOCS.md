# Freebuff CLI

Terminal web contenant la CLI [Freebuff](https://freebuff.com/cli) : un agent de code qui lit,
modifie et teste des fichiers dans le dossier où vous le lancez.

## Première connexion

1. Ouvrez **Freebuff** dans la barre latérale de Home Assistant.
2. Tapez `freebuff login` puis Entrée.
3. Un lien `https://freebuff.com/login?...` s'affiche. Copiez-le (ou cliquez avec Ctrl/Cmd + clic)
   et ouvrez-le sur votre téléphone ou votre ordinateur, puis connectez-vous.
4. Revenez au terminal : il passe tout seul à l'état connecté.

Le panneau est réservé aux comptes **administrateurs** (`panel_admin: true`) : le terminal tourne
en root avec `/homeassistant` et `/share` montés en lecture/écriture, il n'est donc pas proposé aux
autres comptes de l'instance, qui ne voient pas l'icône.

La session est stockée dans `/data/freebuff/.config/manicode/credentials.json` : elle survit aux redémarrages et aux mises à jour de l'add-on.
Pour la révoquer, tapez `freebuff logout`.

## Travailler sur vos add-ons

```bash
cd /local_apps
ls
cd /local_apps/mon-add-on
freebuff
```

Les dossiers accessibles depuis l'add-on :

| Chemin | Contenu | Accès |
| --- | --- | --- |
| `/local_apps` | vos add-ons locaux (dossier `/addons` de HA) | lecture/écriture |
| `/homeassistant` | votre configuration Home Assistant | lecture/écriture |
| `/share` | dossier partagé (pratique pour cloner un dépôt GitHub) | lecture/écriture |
| `/data` | données persistantes de l'add-on | lecture/écriture |

Pour un dépôt GitHub, clonez-le plutôt dans `/share` :

```bash
cd /share
git clone https://github.com/mon-compte/mon-projet.git
cd mon-projet
freebuff
```

Git vous demandera un **token personnel** (GitHub → Settings → Developer settings → Personal access tokens)
comme mot de passe, ce qui est normal : les add-ons ne peuvent pas ouvrir de navigateur pour un OAuth.

Si vous renseignez l'option `github_token`, ce token est utilisé automatiquement par `git` : les
`push` et `pull` vers GitHub fonctionnent sans rien saisir, y compris pour l'agent. Le token doit
autoriser le contenu (`Contents: read/write`) sur les dépôts concernés.

## Options

| Option | Description |
| --- | --- |
| `git_name` | Nom utilisé pour les commits créés par l'agent |
| `git_email` | E-mail utilisé pour les commits créés par l'agent |
| `extra_packages` | Paquets Debian à installer au démarrage (ex. `python3`, `build-essential`) |
| `github_token` | Jeton d'accès GitHub utilisé par `git` pour push/pull sans saisie manuelle (facultatif) |
| `home_assistant_url` | Adresse de votre instance, ex. `http://homeassistant:8123` ou `https://ha.exemple.ca` (facultatif, défaut `http://homeassistant:8123`) |
| `home_assistant_port` | Port de l'API si l'URL n'en contient pas (facultatif, défaut `8123`) |
| `home_assistant_token` | Jeton d'accès longue durée d'un compte Home Assistant dédié (facultatif, secret) |
| `ha_mcp_enabled` | Bascule du serveur MCP Home Assistant (défaut `true`) |
| `ha_mcp_url` | URL du serveur MCP de Home Assistant autre que `/api/mcp` de votre instance, ex. HA-MCP sur `http://homeassistant.local:9584/private_…` (facultatif) |
| `ha_mcp_token` | Jeton demandé par ce serveur, s'il diffère du jeton longue durée (facultatif, secret) |
| `n8n_mcp_enabled` | Bascule du serveur MCP d'un add-on n8n (défaut `false`) |
| `n8n_mcp_url` | URL du serveur MCP n8n, ex. `http://6560bdea-hass-n8n:5678/mcp-server/http` (facultatif) |
| `n8n_mcp_token` | Clé API n8n utilisée comme jeton `Bearer` (facultatif, secret — un jeton Home Assistant y donne `401 unknown-issuer`) |
| `mcp_url` | **Dépréciée** — remplacée par `ha_mcp_url`, reprise tant que celle-ci est vide (migration) |
| `mcp_token` | **Dépréciée** — remplacée par `ha_mcp_token`, reprise tant que celle-ci est vide (migration) |

Les options `home_assistant_*` et `*_mcp_*` sont lues **au démarrage de l'add-on** : redémarrez l'add-on
après les avoir modifiées. Elles ne sont jamais écrites dans un fichier de l'add-on — les jetons ne
vivent que dans l'environnement du terminal, comme `github_token`.

La page de configuration masque les champs `password` : on ne peut pas relire un jeton enregistré.
Le journal donne donc, à chaque démarrage, l'empreinte de chacun — longueur et émetteur `iss` du JWT,
jamais la valeur :

```
INFO: Empreinte des jetons MCP : ha_mcp_token=183 caractères (iss 6750ad00…), n8n_mcp_token=272 caractères (iss n8n)
```

C'est ce qui distingue un jeton Home Assistant d'une clé n8n (même forme, longueur différente) et
qui révèle une valeur collée dans le mauvais champ. Si `n8n_mcp_token` est identique au jeton Home
Assistant, le démarrage le signale aussi : n8n le refuse avec `401 unknown-issuer`.

Les bascules `ha_mcp_enabled` et `n8n_mcp_enabled` servent exactement à cela : mettre un serveur en
pause sans effacer son URL ni son jeton. Une bascule à `false` retire l'entrée du fichier MCP et
laisse les identifiants en place pour la réactivation.

Les anciennes options `mcp_url`/`mcp_token` sont **conservées le temps de la migration** : tant que
`ha_mcp_url` et `ha_mcp_token` sont vides, l'add-on reprend leurs valeurs, donc rien n'est perdu à la
mise à jour. Recopiez-les dans les nouvelles options puis videz les anciennes — l'avertissement du
journal cesse alors. Dès que `ha_mcp_url` et `ha_mcp_token` sont renseignées (vérifiable dans
`/data/options.json`), vider les anciennes est sans effet sur le comportement : le repli ne s'active
que si les deux nouvelles sont vides, et cela retire deux champs de la page de configuration. Elles
restent déclarées dans `config.yaml` parce que le Supervisor supprime de `options.json` toute option
absente du schéma : les retirer tout de suite aurait effacé l'URL avant la reprise.

## Téléphone et tablette

La page servie par ttyd reçoit au build un petit fragment (`freebuff/mobile.html`, inséré par
`build-index.mjs`) destiné aux écrans tactiles. ttyd et xterm.js ne sont pas modifiés : ce sont des
styles et des écouteurs d'événements ajoutés à la page.

- **Défilement au doigt** : un glissement vertical sur le terminal est traduit en crans de molette,
  donc reçu comme une vraie molette par le programme du terminal — tmux (`mouse on`, historique de
  50 000 lignes) ou la TUI Freebuff elle-même. La conversation remonte au doigt, avec un peu
  d'inertie quand le geste est rapide ; un geste horizontal reste au navigateur.
- **Mise en page** : la balise `viewport` manquait (iOS affichait la page en 980 px de large puis la
  dézoomait) ; plus de rebond élastique ni de « tirer pour rafraîchir » sur la zone du terminal.
- **Claviers à prédiction** : le champ de saisie caché de xterm, déporté hors écran (`left:-9999em`)
  et de taille nulle, est ramené dans la page et fixé à 16 px — c'est ce positionnement qui faisait
  perdre la composition à SwiftKey, et une taille inférieure à 16 px qui déclenchait le zoom
  automatique de Safari. Autocorrection et majuscule automatique sont désactivées (les commandes
  sont sensibles à la casse) et `enterkeyhint="send"` annonce une touche d'envoi.

Ce qui reste limité par xterm.js : la prédiction s'affiche dans le clavier, pas dans le terminal, et
un mot remplacé par le clavier peut arriver en plusieurs morceaux. Pour les commandes, mieux vaut
taper mot par mot que compter sur l'autocorrection.

Sur ordinateur, `mouse on` réserve le glissement de souris à tmux : pour sélectionner du texte à la
souris, maintenez **Maj** pendant le glissement. `Ctrl+B [` entre dans le mode copie (`q` pour en
sortir).

Ces correctifs sont appliqués au build : après une mise à jour de l'add-on, l'interface est
régénérée à partir de la version de ttyd installée.

## Accès à l'API Home Assistant locale

Créez un compte Home Assistant dédié avec les permissions nécessaires, puis générez pour ce compte
un jeton d'accès longue durée depuis son profil. Enregistrez-le dans `home_assistant_token`.

Le terminal reçoit alors :

| Variable | Valeur |
| --- | --- |
| `HA_URL` | `home_assistant_url` + `home_assistant_port` (ex. `http://homeassistant:8123`) |
| `HA_TOKEN` | le jeton longue durée |
| `HOME_ASSISTANT_TOKEN` | identique à `HA_TOKEN` |
| `HA_PORT` | le port seul |

Sans jeton configuré, `HA_URL` vaut `http://supervisor/core` et `HA_TOKEN` le jeton éphémère du
Supervisor (permission `homeassistant_api`) : l'API reste utilisable, sans secret stocké.

Exemple — vérifier la configuration avant de recharger :

```bash
curl -s -H "Authorization: Bearer $HA_TOKEN" \
     -H 'Content-Type: application/json' -d '{}' \
     "$HA_URL/api/services/homeassistant/check_config"
# {"result": "valid"}  -> on peut recharger
curl -s -X POST -H "Authorization: Bearer $HA_TOKEN" \
     -H 'Content-Type: application/json' -d '{}' \
     "$HA_URL/api/services/automation/reload"
```

Accordez au compte dédié uniquement les accès nécessaires et révoquez son jeton depuis son profil
si besoin.

## Outils MCP (facultatif)

Si votre instance expose un serveur MCP, l'add-on écrit `/local_apps/.agents/mcp.json` au démarrage.
La CLI Freebuff y voit alors les outils MCP de Home Assistant — édition des tableaux de bord,
lecture/écriture des fichiers YAML avec sauvegarde intégrée, `check_config`, traces d'automatisation,
statistiques, recherche d'entités — **en plus** de l'API REST.

Deux serveurs peuvent cohabiter, chacun avec sa bascule : Home Assistant (`ha_mcp_*`, écrit sous le
nom `homeassistant`) et n8n (`n8n_mcp_*`, écrit sous le nom `n8n`). Seuls les serveurs activés et
joignables apparaissent dans le fichier ; l'un peut être en panne sans priver l'agent de l'autre.

L'API REST reste le repli : sans serveur MCP joignable, aucun fichier n'est écrit et l'agent
travaille exactement comme avant. Rien n'est requis dans les options pour les deux premiers cas.

| Serveur MCP | URL | Jeton |
| --- | --- | --- |
| Intégration intégrée **Model Context Protocol** (HA 2025.2+, [page officielle](https://www.home-assistant.io/integrations/mcp_server/)) | `http://homeassistant:8123/api/mcp`, ou une URL par jeu d'outils (ex. `/api/mcp/assist`) | `home_assistant_token` — **défaut, rien à configurer** |
| Composant tiers exposant `/api/mcp` | idem | idem |
| Intégration **MCP Server (HTTP Transport)** (`mcp_server_http_transport`, dépôt Ganhammar) | `http://homeassistant.local:8123/api/mcp_http` | `home_assistant_token` |
| Composant **HA-MCP** in-process (`ha_mcp_tools`, HACS/Marketplace, HA 2026.11+) | URL de connexion de l'entrée *Configure* : `http://<ip>:9584/private_<secret>` ou `https://<domaine>/api/webhook/<id>` | aucun en mode « Secret URL » |
| App **HA-MCP** (`homeassistant-ai/ha-mcp`, port 9584) | `http://homeassistant.local:9584/private_<secret>` (affiché dans les journaux de l'app) | aucun : le chemin secret *est* l'authentification |
| `hass-mcp` (`/api/hass_mcp`) ou `ha-mcp-web` (port 8086, `/mcp`) | l'URL exacte du serveur | `ha_mcp_token` si le serveur en exige un |
| Add-on **n8n** (serveur MCP intégré) | `http://<slug-de-l-add-on>:5678/mcp-server/http` | `n8n_mcp_token` (clé API n8n) |

- **Adresse par défaut** : `home_assistant_url` + `home_assistant_port` + `/api/mcp`. Elle convient à
  l'intégration intégrée comme aux composants qui réutilisent ce chemin, avec le même jeton.
- **Autre serveur** : renseignez `ha_mcp_url` (URL complète, port compris). Sans `ha_mcp_token`,
  aucun en-tête `Authorization` n'est envoyé vers une autre origine — voulu pour HA-MCP, où le jeton
  Home Assistant n'a rien à faire dans un autre conteneur.
- **Aucun secret dans le fichier** : l'en-tête contient `Bearer $HOME_ASSISTANT_TOKEN`, ou
  `Bearer $HA_MCP_TOKEN` / `Bearer $N8N_MCP_TOKEN` pour un serveur d'une autre origine, que la CLI
  résout depuis l'environnement du terminal.
- **Détection** : le fichier n'est écrit que si le serveur répond à une poignée de main MCP (6 s de
  délai maximum). Sinon le journal de l'add-on affiche un avertissement et l'API REST prend le relais.
- **Sans jeton longue durée** : pas de MCP. Le proxy Supervisor (`http://supervisor/core`) ne relaie
  pas `/api/mcp` (réponse 502 constatée), alors que les routes REST fonctionnent.
- **Port** : une URL sans port explicite part sur le port 80. Si l'hôte est celui de Home
  Assistant, l'add-on complète avec `home_assistant_port` et l'écrit dans le journal ; sinon il
  vous prévient. Donnez toujours l'URL complète, port compris.
- **Jeton** : sur la même origine que Home Assistant (même schéma, hôte et port), le jeton longue
  durée est réutilisé sans `ha_mcp_token`. Pour un autre conteneur, renseignez le jeton du serveur :
  sans lui, aucun en-tête n'est envoyé, donc pas de fuite du jeton Home Assistant.
- **n8n** : l'add-on n8n n'est joignable que par son **nom de conteneur** (le port 5678 n'est pas
  publié sur l'hôte) : `http://<slug>:5678/mcp-server/http`, où le slug est celui de l'URL d'ingress
  (`http://homeassistant.local:8123/6560bdea_hass-n8n` → `6560bdea-hass-n8n`). Côté n8n, activez
  l'accès MCP au niveau de l'instance, créez une clé API (l'OAuth demande un navigateur), et cochez
  « Available in MCP » sur chaque workflow à rendre accessible. La création et l'édition de
  workflows demandent n8n 2.13 ou plus récent.
- **Fichier géré** : le fichier appartient à l'add-on tant qu'il porte sa forme exacte. Il est
  réécrit quand les options changent (empreinte dans `/data/mcp-managed.json`, copie de l'ancien
  dans `/data/mcp-backups`), et les fichiers écrits par les versions précédentes sont repris en
  main au premier démarrage.
- **Fichier personnalisé** : dès que vous le modifiez à la main (autre contenu que celui produit
  par l'add-on), il n'est plus touché. Le journal indique alors l'adresse qu'il contient réellement,
  souvent l'ancienne : corrigez l'option ou supprimez le fichier pour le régénérer.
- **Autorisation** : au premier lancement dans un dossier contenant `.agents/`, la CLI demande
  l'autorisation de charger ces fichiers (dont `mcp.json`). Répondez oui une fois ; pour un
  lancement non interactif, `freebuff --trust-agents` l'accepte d'emblée. Si vous préférez ne rien
  charger, refusez : l'agent travaille alors avec la seule API REST, et supprimer
  `/local_apps/.agents/mcp.json` suffit à faire disparaître l'invite.
- **Formes d'URL vérifiées** : l'intégration intégrée (`/api/mcp`, y compris une URL par jeu
  d'outils comme `/api/mcp/assist`), **MCP Server (HTTP Transport)** de Ganhammar (`/api/mcp_http`)
  et **HA-MCP** (app ou composant, chemin secret) produisent le même fichier `mcpServers` en
  `type: "http"` ; seuls l'URL et l'en-tête changent.
- **Un seul serveur par client** : HA-MCP demande explicitement de ne pas cumuler deux installations
  du même serveur (composant, app, Docker, stdio) dans un même client — deux entrées vers le même
  serveur provoquent des blocages. L'add-on n'en écrit jamais deux pour un même serveur ; deux
  serveurs **différents** (Home Assistant et n8n) cohabitent sans problème.
- **Pas de stdio** : l'add-on n'écrit que du transport HTTP. Un serveur lancé par commande
  (`command`/`args`) n'est jamais généré, et l'ajouter à la main rend le fichier « personnalisé » :
  il ne suit alors plus les options.
- **HA-MCP en mode `ha_auth`** : ce mode remplace le chemin secret par une connexion Home Assistant
  (OAuth) ; un en-tête `Bearer` n'y suffit pas. Pour un accès sans jeton, gardez le mode
  « Secret URL » (ou le webhook).
- **Conflit `/api/mcp`** : si l'intégration intégrée et celle de Ganhammar coexistent, Home Assistant
  attribue `/api/mcp` à la première enregistrée — souvent l'intégrée, qui n'expose que les outils
  Assist. Ganhammar lève alors un problème de réparation et ne sert plus que `/api/mcp_http`.
  Renseignez `ha_mcp_url` explicitement pour ne pas dépendre de cet ordre.
- `AGENTS.md` impose à l'agent de sauvegarder avant d'écrire, de valider ensuite, et de ne jamais
  redémarrer Home Assistant ni supprimer quoi que ce soit, y compris via les outils MCP.

## Garde-fous de l'agent

Au démarrage, l'add-on installe `/local_apps/AGENTS.md` : un rappel du contexte (agent dans un
add-on Home Assistant) et des règles que l'agent doit suivre — changements non destructifs,
sauvegarde préalable, validation de la configuration obligatoire avant de poursuivre, restauration
en cas d'échec, pas de redémarrage de Home Assistant.

Ce fichier est réécrit au démarrage tant qu'il commence par la ligne
`<!-- freebuff-addon-guardrails -->`. Si vous écrivez votre propre `AGENTS.md` (autre première
ligne), l'add-on le laisse intact : ajoutez-y vos consignes, elles seront lues par l'agent.

**Portée** : `AGENTS.md` est lu par l'agent lorsqu'il travaille dans `/local_apps` ou un de ses
sous-dossiers. Pour un dépôt cloné dans `/share`, copiez-y le fichier
(`cp /local_apps/AGENTS.md /share/mon-projet/AGENTS.md`) si vous voulez les mêmes garde-fous.

## Notes

- La CLI Freebuff reste interactive et s'utilise dans le terminal web.
- Après une mise à jour de l'add-on, `freebuff` est réinstallé à sa dernière version au build.
- Si vous êtes sur Raspberry Pi / HA Green / HA Yellow (arm64) et que le build échoue,
  retirez `aarch64` de la liste `arch` dans `config.yaml`.
