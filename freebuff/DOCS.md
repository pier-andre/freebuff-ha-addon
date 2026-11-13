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
| `home_assistant_token` | Jeton d'accès longue durée d'un compte Home Assistant dédié (facultatif, secret) |

## Accès à l'API Home Assistant locale

Créez un compte Home Assistant dédié avec les permissions nécessaires, puis générez pour ce compte
un jeton d'accès longue durée depuis son profil. Enregistrez-le dans `home_assistant_token` dans la
configuration de l'add-on. Il est injecté dans l'environnement du terminal sous `HOME_ASSISTANT_TOKEN`
et `HA_TOKEN`; l'adresse locale est disponible sous `HA_URL` (`http://homeassistant:8123`).
L'option est un champ secret et le jeton n'est pas écrit dans les fichiers de l'add-on. Accordez au
compte dédié uniquement les accès nécessaires et révoquez son jeton depuis son profil si besoin.

## Notes

- La CLI Freebuff reste interactive et s'utilise dans le terminal web.
- Après une mise à jour de l'add-on, `freebuff` est réinstallé à sa dernière version au build.
- Si vous êtes sur Raspberry Pi / HA Green / HA Yellow (arm64) et que le build échoue,
  retirez `aarch64` de la liste `arch` dans `config.yaml`.
