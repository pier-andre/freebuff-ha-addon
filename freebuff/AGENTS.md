<!-- freebuff-addon-guardrails -->
# Contexte : agent Freebuff dans l'add-on Home Assistant

Tu tournes **dans l'add-on « Freebuff CLI » d'une instance Home Assistant**, pas sur un poste de
travail. Ce terminal est lancé en `root` et les dossiers de l'instance sont montés en lecture/écriture.
Une erreur ici peut empêcher Home Assistant de démarrer : traite chaque écriture comme une
modification de production.

| Chemin | Contenu | Accès |
| --- | --- | --- |
| `/homeassistant` | configuration HA (`configuration.yaml`, `automations.yaml`, `scripts.yaml`, `packages/`, `.storage/`) | lecture/écriture |
| `/local_apps` | add-ons locaux (dossier `/addons` de HA) | lecture/écriture |
| `/share` | dossier partagé | lecture/écriture |
| `/data` | données persistantes de cet add-on (session Freebuff, options) | lecture/écriture |

Variables d'environnement disponibles : `HA_URL` et `HA_TOKEN` (jeton longue durée d'un compte
dédié, ou jeton éphémère du proxy Supervisor), `HA_PORT`, `GH_TOKEN` pour `git`, et `MCP_TOKEN`
quand l'option `mcp_token` est renseignée.

## Règles absolues

1. **Non destructif uniquement.** Interdits sans demande explicite de l'utilisateur : supprimer ou
   écraser un fichier de configuration, `rm -rf`, vider `/homeassistant/.storage`, modifier
   `secrets.yaml`, toucher à `/data` (session, options, identifiants), changer les fichiers de
   l'add-on lui-même, ou exécuter `git push` / `git reset --hard` / `git clean`.
2. **Sauvegarder avant d'écrire.** Copie datée à côté du fichier
   (`cp fichier fichier.bak-$(date +%Y%m%d-%H%M%S)`) ou commit dans un dépôt Git avant modification.
3. **Annoncer avant d'agir.** Décris les fichiers et les lignes que tu vas changer, puis attends
   l'accord si l'utilisateur n'a pas déjà demandé explicitement cette modification.
4. **Valider après chaque modification, avant de continuer.** Voir la section suivante. Aucun
   changement n'est « terminé » tant que la validation n'a pas réussi.
5. **Si la validation échoue : restaurer immédiatement** la sauvegarde et s'arrêter. Ne jamais
   enchaîner un second correctif à l'aveugle sur une configuration invalide.
6. **Ne jamais redémarrer ni arrêter Home Assistant** (`homeassistant.restart`, `homeassistant.stop`,
   redémarrage du Supervisor) : demande-le à l'utilisateur.
7. **Aucun secret en clair** : ne lis pas `secrets.yaml` sans nécessité, ne recopie jamais un jeton
   dans un fichier, un commit ou une sortie de commande.

## Valider la configuration avant de poursuivre

La CLI `ha` **n'existe pas dans ce conteneur** : la commande `ha core check` n'y est pas disponible.
La validation équivalente se fait par l'API :

```bash
curl -s -H "Authorization: Bearer $HA_TOKEN" \
     -H 'Content-Type: application/json' -d '{}' \
     "$HA_URL/api/services/homeassistant/check_config"
```

- Réponse attendue : `{"result": "valid"}`. Tout autre résultat (`"invalid"`, code HTTP 401/403)
  équivaut à un échec : **restaure la sauvegarde**.
- Si `ha` est disponible (autre environnement), `ha core check` fait la même vérification.
- Un `401` signifie que le jeton est absent ou expiré : signale-le à l'utilisateur au lieu de
  modifier la configuration.

Après validation réussie, recharge ce qui est nécessaire plutôt que de redémarrer :
`automation.reload`, `script.reload`, `scene.reload`, `template.reload` via
`POST $HA_URL/api/services/<domaine>/reload`.

## Serveur MCP (si présent)

Quand `/local_apps/.agents/mcp.json` existe et que le serveur répond, tu disposes en plus des outils
MCP de Home Assistant (`get_dashboard_config`, `patch_dashboard_config`, `save_config_file`,
`check_config`, `get_trace`, `search_entities`…). C'est un confort par-dessus **la même instance** :
jamais une seconde instance, jamais un accès distant. L'API REST (`$HA_URL`, `$HA_TOKEN`) reste la
voie de repli et fait foi en cas de désaccord entre les deux.

- `backup_config_files` avant tout `save_config_file` ou `batch_edit_config_files`, puis
  `check_config` et `restore_config_backup` si la validation échoue : les règles ci-dessus
  s'appliquent aux outils MCP exactement comme aux fichiers.
- Jamais `restart_ha`, `delete_config_file`, `delete_dashboard_config`, `delete_automation`,
  `delete_entity`, `clear_statistics`, `adjust_statistics` ni `update_entity_registry` sans demande
  explicite de l'utilisateur.
- Tableaux de bord : préférer `patch_dashboard_config` (JSON Patch, édition partielle) à
  `save_dashboard_config` (remplacement complet), et relire avec `get_dashboard_config`.
- Ces outils viennent d'un composant tiers (`mcp_server`, `mcp_server_http_transport`, HA-MCP…) :
  ils changent d'une version à l'autre. Si un outil manque ou échoue, reviens à l'API REST et
  signale-le au lieu de contourner le garde-fou.

## Cas particuliers

- **Tableaux de bord** : ils vivent dans `/homeassistant/.storage/lovelace.*` (JSON, `mode: storage`).
  Home Assistant les garde en mémoire et réécrit ces fichiers : une modification directe peut être
  perdue. Passe par l'API WebSocket `lovelace/config/save`, ou demande un redémarrage.
- **Packages** : `configuration.yaml` charge `packages: !include_dir_named packages`; un fichier
  invalide dans `packages/` casse tout le chargement.
- **YAML** : deux espaces d'indentation, pas de tabulations, guillemets autour des gabarits `{{ }}`
  sensibles. Aucun outil `yq`/`python3` n'est installé : relis le diff avant de valider.
- **Vérifie toujours `git status` / `git diff`** dans un dépôt avant de conclure.

## Ton de travail

Réponds en français si l'utilisateur écrit en français. Explique le « pourquoi » d'un changement,
montre le diff, et termine par ce qui a été validé (ou ce qui reste à valider par l'utilisateur).
