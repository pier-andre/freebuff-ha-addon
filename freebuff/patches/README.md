# Correctifs locaux de Freebuff2API

Freebuff2API est compilé depuis les sources à chaque build de l'add-on
(`api-builder` dans le `Dockerfile`). Les correctifs de ce dossier sont
appliqués avec `git apply` juste après le clone, avant `go build`.

## `0001-freebuff-model-catalog.patch`

Corrige deux défauts constatés en usage réel : `/v1/models` n'exposait plus
qu'un seul modèle (`google/gemini-2.5-flash-lite`, retiré par Freebuff) et les
requêtes échouaient par vagues de `502 upstream run expired twice in a row`
après un `free session invalid`.

### Liste de modèles

La liste est lue depuis `GET /api/v1/freebuff/models` — le point d'entrée qui
alimente la commande `/model` de la CLI, et non plus par extraction des
littéraux de `free-agents.ts`, qui ne correspondent plus au code actuel.

Le catalogue est propre à chaque compte : chaque ligne fournit un nom affiché
(`displayName`), une clé (`key`) et un handle opaque (`handle`). L'API expose
les noms affichés comme identifiants de modèle et transmet le handle de la
ligne demandée au moment de la requête, avec les en-têtes du protocole
catalogue (`x-freebuff-catalog-protocol`, `x-freebuff-model`,
`x-freebuff-catalog-fetch`, `x-freebuff-client: cli`). Les lignes
`access: "locked"` sont ignorées.

La liste est rafraîchie avant l'expiration annoncée par `refreshAt` (bornée
entre 2 et 30 minutes). Un handle qui change invalide la session free et les
runs en cours, qui sont reconstruits à la requête suivante. Si le catalogue
est momentanément inaccessible, la liste précédente est conservée ; avant le
premier succès, une table de secours de modèles hérités est utilisée.

### Sessions et runs

Une session free n'est admise que pour un couple modèle/handle donné ; en
changer abandonne la session et tous ses runs. Et lorsqu'une session est
refusée (`session_expired`, `session_superseded`, `waiting_room_*`,
`freebuff_update_required`), le run associé est désormais invalidé lui aussi.
Auparavant seule la session était recréée et la requête rejouait le même
`run_id`, mort avec l'ancienne session, d'où le `502` après une deuxième
tentative.

## Mettre à jour ou régénérer un correctif

```sh
git clone --depth 1 https://github.com/Quorinex/Freebuff2API.git /tmp/f2a
cd /tmp/f2a
# appliquer le correctif existant puis modifier les sources
git apply -p1 --whitespace=nowarn /chemin/vers/freebuff/patches/0001-*.patch
# ... éditer, puis
git add -A
git diff --cached --binary > /chemin/vers/freebuff/patches/0001-freebuff-model-catalog.patch
```

Vérifier l'application et la compilation avant de committer :

```sh
git apply -p1 --check /chemin/vers/freebuff/patches/0001-*.patch
CGO_ENABLED=0 go build -o /tmp/Freebuff2API . && go vet ./...
```

`FREEBUFF2API_REF` (par défaut `main`) fixe le commit amont utilisé. Un
changement de ce côté peut rendre le correctif inapplicable : le build échoue
alors franchement, ce qui est préférable à une image silencieusement non
corrigée.
