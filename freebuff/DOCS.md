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
| `mcp_url` | URL d'un serveur MCP autre que `/api/mcp` de votre instance, ex. HA-MCP sur `http://homeassistant.local:9583/private_…` (facultatif) |
| `mcp_token` | Jeton demandé par ce serveur MCP, s'il en exige un (facultatif, secret) |

Les trois options `home_assistant_*` sont lues **au démarrage de l'add-on** : redémarrez l'add-on après
les avoir modifiées. Elles ne sont jamais écrites dans un fichier de l'add-on — le jeton ne vit que
dans l'environnement du terminal, comme `github_token`.

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

L'API REST reste le repli : sans serveur MCP joignable, aucun fichier n'est écrit et l'agent
travaille exactement comme avant. Rien n'est requis dans les options pour les deux premiers cas.

| Serveur MCP | URL | Jeton |
| --- | --- | --- |
| Intégration intégrée « Model Context Protocol Server » (HA 2025.2+) | `http://homeassistant:8123/api/mcp` | `home_assistant_token` — **défaut, rien à configurer** |
| Composant tiers exposant `/api/mcp` | idem | idem |
| Intégration **MCP Server (HTTP Transport)** (`mcp_server_http_transport`) | `http://homeassistant.local:8123/api/mcp_http` | `home_assistant_token` |
| App **HA-MCP** du Marketplace (`homeassistant-ai/ha-mcp`, port 9583) | `http://homeassistant.local:9583/<chemin secret>` (affiché dans les journaux de l'app) | aucun : le chemin secret *est* l'authentification |
| `hass-mcp` (`/api/hass_mcp`) ou `ha-mcp-web` (port 8086, `/mcp`) | l'URL exacte du serveur | `mcp_token` si le serveur en exige un |

- **Adresse par défaut** : `home_assistant_url` + `home_assistant_port` + `/api/mcp`. Elle convient à
  l'intégration intégrée comme aux composants qui réutilisent ce chemin, avec le même jeton.
- **Autre serveur** : renseignez `mcp_url` (URL complète, port compris). Sans `mcp_token`, aucun
  en-tête `Authorization` n'est envoyé vers une autre origine — voulu pour HA-MCP, où le jeton Home
  Assistant n'a rien à faire dans un autre conteneur.
- **Aucun secret dans le fichier** : l'en-tête contient `Bearer $HOME_ASSISTANT_TOKEN` (ou
  `Bearer $MCP_TOKEN` pour `mcp_token`), que la CLI résout depuis l'environnement du terminal.
- **Détection** : le fichier n'est écrit que si le serveur répond à une poignée de main MCP (6 s de
  délai maximum). Sinon le journal de l'add-on affiche un avertissement et l'API REST prend le relais.
- **Sans jeton longue durée** : pas de MCP. Le proxy Supervisor (`http://supervisor/core`) ne relaie
  pas `/api/mcp` (réponse 502 constatée), alors que les routes REST fonctionnent.
- **Port** : un `mcp_url` sans port explicite part sur le port 80. Si l'hôte est celui de Home
  Assistant, l'add-on complète avec `home_assistant_port` et l'écrit dans le journal ; sinon il
  vous prévient. Donnez toujours l'URL complète, port compris.
- **Jeton** : sur la même origine que Home Assistant (même schéma, hôte et port), le jeton longue
  durée est réutilisé sans `mcp_token`. Pour un autre conteneur, renseignez `mcp_token` : sans lui,
  aucun en-tête n'est envoyé, donc pas de fuite du jeton Home Assistant.
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
