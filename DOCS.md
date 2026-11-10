# Freebuff CLI

Terminal web contenant la CLI [Freebuff](https://freebuff.com/cli) : un agent de code qui lit,
modifie et teste des fichiers dans le dossier où vous le lancez.

## Première connexion

1. Ouvrez **Freebuff** dans la barre latérale de Home Assistant.
2. Tapez `freebuff login` puis Entrée.
3. Un lien `https://freebuff.com/login?...` s'affiche. Copiez-le (ou cliquez avec Ctrl/Cmd + clic)
   et ouvrez-le sur votre téléphone ou votre ordinateur, puis connectez-vous.
4. Revenez au terminal : il passe tout seul à l'état connecté.

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
| `api_enabled` | Active le proxy OpenAI compatible sur le réseau local (désactivé par défaut) |
| `freebuff_auth_tokens` | Jeton manuel de repli si le fichier d'identifiants CLI n'est pas disponible (facultatif) |
| `api_keys` | Clé(s) client(s) exigée(s) par l'API (séparées par des virgules) |
| `github_token` | Jeton d'accès GitHub utilisé par `git` pour push/pull sans saisie manuelle (facultatif) |

## API sur le réseau local

Activez `api_enabled` et renseignez `api_keys` dans les options. Freebuff2API lit automatiquement
le jeton `authToken` du fichier de session créé par `freebuff login`; `freebuff_auth_tokens` ne sert
que de solution de repli manuelle. Si aucun identifiant n'existe au démarrage, connectez-vous dans le
terminal puis redémarrez l'add-on. Freebuff2API
écoute ensuite sur le port TCP **11436** de l'hôte Home Assistant. Les clients utilisent l'URL de base
`http://ADRESSE_IP_DE_HOME_ASSISTANT:11436/v1` et la clé configurée dans `api_keys` comme clé API.
Les modèles disponibles sont ceux renvoyés par le proxy (par exemple via `/v1/models`). L'API ne
nécessite pas que le terminal interactif reste ouvert. Le jeton CLI est stocké dans `/data`; protégez
l'accès à Home Assistant et n'exposez pas le port 11436 à Internet.

## Notes

- La CLI Freebuff reste interactive et s'utilise dans le terminal web. Pour les clients OpenAI compatibles,
  utilisez le proxy Freebuff2API activable dans les options.
- Après une mise à jour de l'add-on, `freebuff` est réinstallé à sa dernière version au build.
- Si vous êtes sur Raspberry Pi / HA Green / HA Yellow (arm64) et que le build échoue,
  retirez `aarch64` de la liste `arch` dans `config.yaml`.
