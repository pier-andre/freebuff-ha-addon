#!/usr/bin/env bash
# Écrit /local_apps/.agents/mcp.json pour la CLI Freebuff (format `mcpServers`).
#
# Deux serveurs MCP peuvent cohabiter, chacun avec sa bascule :
#   homeassistant   ha_mcp_enabled   ha_mcp_url   ha_mcp_token
#   n8n             n8n_mcp_enabled  n8n_mcp_url  n8n_mcp_token
# Seuls les serveurs activés *et* joignables sont écrits : un serveur en échec
# n'empêche pas l'autre, et une bascule à false laisse l'entrée de côté sans
# effacer ses identifiants.
#
# Le fichier est « géré » : il suit les options de l'add-on. Trois cas au
# démarrage :
#   1. fichier absent                -> écrit ;
#   2. fichier écrit par l'add-on    -> réécrit si les options ont changé
#                                       (sauvegarde dans /data/mcp-backups) ;
#   3. fichier personnalisé          -> laissé intact, avec un message explicite.
# La propriété du fichier est reconnue par l'empreinte conservée dans
# /data/mcp-managed.json, ou, pour un fichier antérieur à cette empreinte, par sa
# forme exacte (produite par cet add-on uniquement). Les deux bascules à false
# suppriment le fichier géré, après sauvegarde.
#
# Variables d'environnement (fournies par run.sh) :
#   HA_URL, HA_PORT, HOME_ASSISTANT_TOKEN, OPTIONS_FILE
# Surcharges utilisées par les tests : MCP_DST, MCP_STATE, MCP_BACKUP_DIR.
set -u

opts_file=${OPTIONS_FILE:-/data/options.json}
mcp_dst=${MCP_DST:-/local_apps/.agents/mcp.json}
mcp_state=${MCP_STATE:-/data/mcp-managed.json}
mcp_backup_dir=${MCP_BACKUP_DIR:-/data/mcp-backups}
ha_url=${HA_URL:-}
ha_port=${HA_PORT:-8123}

log_info() { printf 'INFO: %s\n' "$*"; }
log_warning() { printf 'AVERTISSEMENT: %s\n' "$*" >&2; }

config_value() {
    jq -r --arg key "$1" '.[$key] // empty' "${opts_file}" 2>/dev/null
}

# Une bascule absente (options.json d'une version antérieure) garde son défaut.
config_bool() {
    local key="$1" default="$2" value
    value="$(jq -r --arg key "${key}" \
        'if type == "object" and has($key) and (.[$key] | type == "boolean")
         then (.[$key] | tostring) else empty end' "${opts_file}" 2>/dev/null)"
    printf '%s' "${value:-${default}}"
}

# --- Adresse des serveurs ----------------------------------------------------
# Un port absent est le piège classique : http://homeassistant.local/api/mcp_http
# part sur le port 80 et reste sans réponse. Si l'hôte est celui de Home
# Assistant, on complète avec `home_assistant_port` et on le dit.
completed_url=''
endpoint_with_port() { # $1 = URL, $2 = nom de l'option (pour le journal)
    local url="$1" label="$2" scheme host path ha_host
    completed_url="${url%/}"
    [[ "${completed_url}" =~ ^([A-Za-z][A-Za-z0-9+.-]*)://([^/]+)(/.*)?$ ]] || return 0
    scheme="${BASH_REMATCH[1]}"
    host="${BASH_REMATCH[2]}"
    path="${BASH_REMATCH[3]:-}"
    [[ "${host}" == *:* ]] && return 0
    ha_host="${ha_url#*://}"
    ha_host="${ha_host%%/*}"
    ha_host="${ha_host%%:*}"
    if [[ -n "${ha_host}" && "${host}" == "${ha_host}" ]]; then
        completed_url="${scheme}://${host}:${ha_port}${path}"
        log_info "${label} sans port : interprété comme ${completed_url}"
    else
        log_warning "${label} sans port explicite (${completed_url}) : port 80 par défaut, à vérifier"
    fi
}

origin_of() {
    local url="$1" scheme rest
    scheme="${url%%://*}"
    rest="${url#*://}"
    rest="${rest%%/*}"
    [[ "${rest}" == *:* ]] || rest="${rest}:80"
    printf '%s://%s' "${scheme}" "${rest}"
}

# --- Poignée de main ---------------------------------------------------------
# Une entrée n'est écrite que si le serveur répond : sinon la CLI garderait un
# serveur mort à chaque démarrage. La raison de l'échec est reportée au journal.
mcp_probe_reason=''
mcp_reachable() {
    local reason
    reason="$(MCP_PROBE_URL="$1" MCP_PROBE_TOKEN="$2" node -e '
const headers = {
  "Content-Type": "application/json",
  "Accept": "application/json, text/event-stream",
};
if (process.env.MCP_PROBE_TOKEN) {
  headers.Authorization = "Bearer " + process.env.MCP_PROBE_TOKEN;
}
fetch(process.env.MCP_PROBE_URL, {
  method: "POST",
  headers,
  signal: AbortSignal.timeout(6000),
  body: JSON.stringify({
    jsonrpc: "2.0",
    id: 1,
    method: "initialize",
    params: {
      protocolVersion: "2025-06-18",
      capabilities: {},
      clientInfo: { name: "freebuff-addon", version: "1" },
    },
  }),
})
  .then((response) => {
    if (response.ok) {
      process.stdout.write("ok");
      process.exit(0);
    }
    process.stdout.write("HTTP " + response.status);
    process.exit(1);
  })
  .catch((error) => {
    const timedOut = error && error.name === "TimeoutError";
    process.stdout.write(timedOut ? "delai depasse (6 s)" : "injoignable");
    process.exit(1);
  });
' 2>/dev/null)"
    mcp_probe_reason="${reason:-injoignable}"
    [[ "${mcp_probe_reason}" == 'ok' ]]
}

# --- Jeton d'un serveur ------------------------------------------------------
# Le jeton reste dans l'environnement, jamais dans le fichier. Le jeton longue
# durée de Home Assistant n'est réutilisé que pour la même origine (même schéma,
# même hôte, même port) : il ne part jamais vers un autre conteneur.
hdr_token=''
probe_token=''
resolve_credentials() { # $1 = URL, $2 = jeton de l'option, $3 = variable exportée
    hdr_token=''
    probe_token=''
    if [[ "$(origin_of "$1")" == "$(origin_of "${ha_url}")" && -n "${HOME_ASSISTANT_TOKEN:-}" ]]; then
        hdr_token='$HOME_ASSISTANT_TOKEN'
        probe_token="${HOME_ASSISTANT_TOKEN}"
    elif [[ -n "$2" ]]; then
        hdr_token="\$$3"
        probe_token="$2"
    fi
}

# --- Serveurs demandés -------------------------------------------------------
srv_name=()      # clé dans mcpServers
srv_url=()
srv_header=()    # '$VAR' écrit dans le fichier, vide si aucun en-tête
srv_probe=()     # jeton réel, utilisé pour la sonde uniquement
srv_label=()
srv_token_opt=()

add_server() {
    srv_name+=("$1")
    srv_url+=("$2")
    srv_header+=("$3")
    srv_probe+=("$4")
    srv_label+=("$5")
    srv_token_opt+=("$6")
}

# Home Assistant : `homeassistant`
ha_mcp_enabled="$(config_bool 'ha_mcp_enabled' 'true')"
ha_mcp_url_opt="$(config_value 'ha_mcp_url')"
ha_mcp_token_opt="$(config_value 'ha_mcp_token')"
if [[ -z "${ha_mcp_url_opt}" && -z "${ha_mcp_token_opt}" ]]; then
    # Options renommées en 0.2.14. Elles restent déclarées dans config.yaml tant
    # que la migration n'est pas faite : le Supervisor retire de options.json ce
    # qui n'est plus au schéma, et la reprise ci-dessous n'aurait alors plus rien
    # à lire. La condition porte sur les deux nouvelles options à la fois pour
    # qu'un jeton d'une autre origine ne soit jamais envoyé à une URL que
    # l'utilisateur vient de changer.
    ha_mcp_url_opt="$(config_value 'mcp_url')"
    ha_mcp_token_opt="$(config_value 'mcp_token')"
    if [[ -n "${ha_mcp_url_opt}${ha_mcp_token_opt}" ]]; then
        log_warning "Options mcp_url/mcp_token dépréciées mais reprises : recopiez-les dans ha_mcp_url/ha_mcp_token, puis videz-les (elles resteront actives d'ici là)"
    fi
fi

if [[ "${ha_mcp_enabled}" != 'true' ]]; then
    log_info "Serveur MCP Home Assistant désactivé (ha_mcp_enabled)"
elif [[ -n "${ha_mcp_url_opt}" ]]; then
    endpoint_with_port "${ha_mcp_url_opt}" 'ha_mcp_url'
    resolve_credentials "${completed_url}" "${ha_mcp_token_opt}" 'HA_MCP_TOKEN'
    add_server 'homeassistant' "${completed_url}" "${hdr_token}" "${probe_token}" \
        'Home Assistant' 'ha_mcp_token'
elif [[ -n "${HOME_ASSISTANT_TOKEN:-}" ]]; then
    # Sans `ha_mcp_url`, on vise /api/mcp de l'instance (intégration intégrée
    # `mcp_server` ou composant qui réutilise ce chemin). Pas de repli
    # Supervisor : http://supervisor/core ne relaie pas /api/mcp (502 constaté),
    # contrairement aux routes REST classiques.
    ha_endpoint="${ha_url%/}/api/mcp"
    resolve_credentials "${ha_endpoint}" "${ha_mcp_token_opt}" 'HA_MCP_TOKEN'
    add_server 'homeassistant' "${ha_endpoint}" "${hdr_token}" "${probe_token}" \
        'Home Assistant' 'ha_mcp_token'
else
    log_info "MCP Home Assistant ignoré : sans jeton longue durée, l'API REST passe par le proxy Supervisor"
fi

# n8n : `n8n` — l'add-on n8n n'est joignable que par son nom de conteneur
# (le port 5678 n'est pas publié sur l'hôte), ex.
# http://6560bdea-hass-n8n:5678/mcp-server/http
n8n_mcp_enabled="$(config_bool 'n8n_mcp_enabled' 'false')"
n8n_mcp_url_opt="$(config_value 'n8n_mcp_url')"
n8n_mcp_token_opt="$(config_value 'n8n_mcp_token')"
if [[ "${n8n_mcp_enabled}" != 'true' ]]; then
    log_info "Serveur MCP n8n désactivé (n8n_mcp_enabled)"
elif [[ -z "${n8n_mcp_url_opt}" ]]; then
    log_warning "n8n_mcp_enabled est actif mais n8n_mcp_url est vide : serveur n8n ignoré"
else
    endpoint_with_port "${n8n_mcp_url_opt}" 'n8n_mcp_url'
    resolve_credentials "${completed_url}" "${n8n_mcp_token_opt}" 'N8N_MCP_TOKEN'
    add_server 'n8n' "${completed_url}" "${hdr_token}" "${probe_token}" \
        'n8n' 'n8n_mcp_token'
fi

# --- Contenu voulu -----------------------------------------------------------
mcp_servers='{}'
mcp_written_urls=()
for i in "${!srv_name[@]}"; do
    if mcp_reachable "${srv_url[i]}" "${srv_probe[i]}"; then
        if [[ -n "${srv_header[i]}" ]]; then
            mcp_servers="$(printf '%s' "${mcp_servers}" | jq \
                --arg name "${srv_name[i]}" --arg url "${srv_url[i]}" --arg token "${srv_header[i]}" \
                '. + {($name): {type: "http", url: $url, headers: {Authorization: ("Bearer " + $token)}}}')"
        else
            mcp_servers="$(printf '%s' "${mcp_servers}" | jq \
                --arg name "${srv_name[i]}" --arg url "${srv_url[i]}" \
                '. + {($name): {type: "http", url: $url}}')"
        fi
        mcp_written_urls+=("${srv_name[i]}=${srv_url[i]}")
    else
        case "${mcp_probe_reason}" in
            'HTTP 401' | 'HTTP 403')
                log_warning "Serveur MCP ${srv_label[i]} : ${mcp_probe_reason} — jeton refusé ou absent (option ${srv_token_opt[i]})"
                ;;
            'HTTP 404')
                if [[ "${srv_name[i]}" == 'n8n' ]]; then
                    log_warning "Serveur MCP n8n injoignable (${srv_url[i]}) : HTTP 404 — vérifiez que l'accès MCP est activé dans n8n (Settings → Instance-level MCP) et que l'URL finit par /mcp-server/http"
                else
                    log_warning "Serveur MCP ${srv_label[i]} injoignable (${srv_url[i]}) : HTTP 404 — vérifiez l'URL ${srv_token_opt[i]%%_token}_url"
                fi
                ;;
            *)
                log_warning "Serveur MCP ${srv_label[i]} injoignable (${srv_url[i]}) : ${mcp_probe_reason}"
                ;;
        esac
    fi
done

# --- Propriété du fichier ----------------------------------------------------
# Formes acceptées comme « écrites par l'add-on » : une ou deux entrées, dont les
# noms sont connus, en transport http, avec au plus un en-tête `Authorization`
# référençant une variable d'environnement (jamais un jeton en clair).
mcp_json="$(printf '%s' "${mcp_servers}" | jq '{mcpServers: .}')"
mcp_wanted="$(printf '%s' "${mcp_json}" | jq -S .)"

# L'empreinte de /data/mcp-managed.json décrit ce que l'add-on a écrit la
# dernière fois : tant que le fichier lui reste identique, il lui appartient,
# même si les options ont changé depuis (serveur retiré, bascules à false...).
# Comparer l'empreinte au *nouveau* contenu ne reconnaîtrait plus le fichier au
# moment précis où il faut le réécrire ou le retirer.
mcp_owned=0
if [[ -f "${mcp_state}" && -f "${mcp_dst}" ]] \
    && [[ "$(jq -S . "${mcp_state}" 2>/dev/null)" == "$(jq -S . "${mcp_dst}" 2>/dev/null)" ]]; then
    mcp_owned=1
fi

if [[ "${mcp_owned}" == '0' && -f "${mcp_dst}" ]] && jq -e '
    (keys == ["mcpServers"])
    and (.mcpServers | type == "object")
    and ((.mcpServers | keys | length) > 0)
    and (((.mcpServers | keys) - ["homeassistant", "n8n"]) == [])
    and ([.mcpServers[] |
          (type == "object")
          and (.type == "http")
          and ((keys - ["headers", "type", "url"]) == [])
          and (has("url") and (.url | type == "string"))
          and ((.headers // {}) |
               if . == {} then true
               else (keys == ["Authorization"])
                    and (.Authorization | test("^Bearer \\$(HOME_ASSISTANT_TOKEN|HA_MCP_TOKEN|N8N_MCP_TOKEN|MCP_TOKEN)$"))
               end)
         ] | all)
' "${mcp_dst}" >/dev/null 2>&1; then
    # Fichier écrit par une version antérieure (aucune empreinte enregistrée) :
    # sa forme ne peut venir que de cet add-on, on le reprend en main.
    mcp_owned=1
    log_info "${mcp_dst} vient d'une version antérieure de l'add-on : repris en main"
fi

mcp_current_servers="$(jq -r '.mcpServers | to_entries[]? | "\(.key)=\(.value.url // "?")"' "${mcp_dst}" 2>/dev/null | awk 'NR > 1 { printf ", " } { printf "%s", $0 }')"

# --- Décision ----------------------------------------------------------------
if [[ "${#mcp_written_urls[@]}" -eq 0 ]]; then
    # Aucun serveur écrit : soit les deux bascules sont à false (l'utilisateur
    # veut se passer de MCP), soit les serveurs activés n'ont pas répondu — auquel
    # cas on garde le fichier existant plutôt que de le vider sur une panne.
    if [[ "${ha_mcp_enabled}" != 'true' && "${n8n_mcp_enabled}" != 'true' ]]; then
        if [[ "${mcp_owned}" == '1' ]]; then
            mkdir -p "${mcp_backup_dir}"
            backup="${mcp_backup_dir}/mcp.json.$(date +%Y%m%d-%H%M%S)"
            cp "${mcp_dst}" "${backup}"
            rm -f "${mcp_dst}" "${mcp_state}"
            log_info "Serveurs MCP désactivés : ${mcp_dst} retiré (sauvegarde : ${backup})"
        elif [[ -f "${mcp_dst}" ]]; then
            log_warning "${mcp_dst} personnalisé : laissé intact malgré les deux bascules à false"
        else
            log_info "Aucun serveur MCP activé : rien à écrire"
        fi
    else
        log_warning "Aucun serveur MCP joignable : ${mcp_dst} laissé en l'état, l'agent garde l'API REST"
        if [[ -n "${mcp_current_servers}" ]]; then
            log_warning "Le fichier contient encore : ${mcp_current_servers}"
        fi
    fi
    exit 0
fi

mcp_written_list="$(printf '%s\n' "${mcp_written_urls[@]}" | awk 'NR > 1 { printf ", " } { printf "%s", $0 }')"

mkdir -p "$(dirname "${mcp_dst}")"
if [[ ! -e "${mcp_dst}" ]]; then
    printf '%s\n' "${mcp_json}" > "${mcp_dst}"
    chmod 644 "${mcp_dst}"
    printf '%s\n' "${mcp_wanted}" > "${mcp_state}"
    log_info "Outils MCP activés : ${mcp_written_list} (${mcp_dst})"
elif [[ "$(jq -S . "${mcp_dst}" 2>/dev/null)" == "${mcp_wanted}" ]]; then
    printf '%s\n' "${mcp_wanted}" > "${mcp_state}"
    log_info "Outils MCP déjà configurés : ${mcp_written_list}"
elif [[ "${mcp_owned}" == '1' ]]; then
    mkdir -p "${mcp_backup_dir}"
    backup="${mcp_backup_dir}/mcp.json.$(date +%Y%m%d-%H%M%S)"
    cp "${mcp_dst}" "${backup}"
    printf '%s\n' "${mcp_json}" > "${mcp_dst}"
    chmod 644 "${mcp_dst}"
    printf '%s\n' "${mcp_wanted}" > "${mcp_state}"
    log_info "Outils MCP mis à jour : ${mcp_current_servers:-?} -> ${mcp_written_list} (sauvegarde : ${backup})"
else
    if [[ -n "${mcp_current_servers}" && "${mcp_current_servers}" == "${mcp_written_list}" ]]; then
        log_warning "${mcp_dst} personnalisé : laissé intact (il ajoute d'autres serveurs ou clés)"
    else
        log_warning "${mcp_dst} personnalisé : laissé intact, il pointe vers ${mcp_current_servers:-?} au lieu de ${mcp_written_list}"
    fi
    log_warning "Pour le régénérer : supprimez ${mcp_dst} puis redémarrez l'add-on"
fi

exit 0
