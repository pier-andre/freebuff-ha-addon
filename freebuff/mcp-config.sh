#!/usr/bin/env bash
# Écrit /local_apps/.agents/mcp.json pour la CLI Freebuff (format `mcpServers`).
#
# Le fichier est « géré » : il suit les options de l'add-on, y compris quand
# l'URL MCP change. Trois cas au démarrage :
#   1. fichier absent                -> écrit ;
#   2. fichier écrit par l'add-on    -> réécrit si les options ont changé (sauvegarde
#                                       préalable dans /data/mcp-backups) ;
#   3. fichier personnalisé          -> laissé intact, avec un message explicite.
# La propriété du fichier est reconnue par l'empreinte conservée dans
# /data/mcp-managed.json, ou, pour un fichier antérieur à cette empreinte, par sa
# forme exacte (produite par cet add-on uniquement).
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

mcp_url_opt="$(config_value 'mcp_url')"
mcp_token_opt="$(config_value 'mcp_token')"

# --- Adresse du serveur ------------------------------------------------------
# Sans `mcp_url`, on vise /api/mcp de l'instance (intégration intégrée
# `mcp_server` ou composant qui réutilise ce chemin).
mcp_endpoint=''
if [[ -n "${mcp_url_opt}" ]]; then
    mcp_endpoint="${mcp_url_opt%/}"
    # Un port absent est le piège classique : http://homeassistant.local/api/mcp_http
    # part sur le port 80 et reste sans réponse. Si l'hôte est celui de Home
    # Assistant, on complète avec `home_assistant_port` et on le dit.
    if [[ "${mcp_endpoint}" =~ ^([A-Za-z][A-Za-z0-9+.-]*)://([^/]+)(/.*)?$ ]]; then
        endpoint_scheme="${BASH_REMATCH[1]}"
        endpoint_host="${BASH_REMATCH[2]}"
        endpoint_path="${BASH_REMATCH[3]:-}"
        ha_host="${ha_url#*://}"
        ha_host="${ha_host%%/*}"
        ha_host="${ha_host%%:*}"
        if [[ "${endpoint_host}" != *:* ]]; then
            if [[ -n "${ha_host}" && "${endpoint_host}" == "${ha_host}" ]]; then
                mcp_endpoint="${endpoint_scheme}://${endpoint_host}:${ha_port}${endpoint_path}"
                log_info "mcp_url sans port : interprété comme ${mcp_endpoint}"
            else
                log_warning "mcp_url sans port explicite (${mcp_endpoint}) : port 80 par défaut, à vérifier"
            fi
        fi
    fi
elif [[ -n "${HOME_ASSISTANT_TOKEN:-}" ]]; then
    # Pas de repli Supervisor ici : http://supervisor/core ne relaie pas
    # /api/mcp (502 constaté), contrairement aux routes REST classiques.
    mcp_endpoint="${ha_url%/}/api/mcp"
else
    log_info "MCP ignoré : sans jeton longue durée, l'API REST passe par le proxy Supervisor"
    exit 0
fi

# --- Jeton -------------------------------------------------------------------
# `mcp_token` reste dans l'environnement, jamais dans le fichier. À défaut, le
# jeton Home Assistant n'est réutilisé que pour la même origine (même schéma,
# même hôte, même port) : il ne part jamais vers un autre conteneur.
origin_of() {
    local url="$1" scheme rest
    scheme="${url%%://*}"
    rest="${url#*://}"
    rest="${rest%%/*}"
    [[ "${rest}" == *:* ]] || rest="${rest}:80"
    printf '%s://%s' "${scheme}" "${rest}"
}

mcp_header_token=''
probe_token=''
if [[ -n "${mcp_token_opt}" ]]; then
    export MCP_TOKEN="${mcp_token_opt}"
    mcp_header_token='$MCP_TOKEN'
    probe_token="${MCP_TOKEN}"
elif [[ -n "${HOME_ASSISTANT_TOKEN:-}" ]] \
    && [[ "$(origin_of "${mcp_endpoint}")" == "$(origin_of "${ha_url}")" ]]; then
    mcp_header_token='$HOME_ASSISTANT_TOKEN'
    probe_token="${HOME_ASSISTANT_TOKEN}"
fi

# --- Poignée de main ---------------------------------------------------------
# Le fichier n'est écrit que si le serveur répond : sinon la CLI garderait un
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

# --- Contenu voulu -----------------------------------------------------------
if [[ -n "${mcp_header_token}" ]]; then
    mcp_json="$(jq -n --arg url "${mcp_endpoint}" --arg token "${mcp_header_token}" \
        '{mcpServers:{homeassistant:{type:"http",url:$url,headers:{Authorization:("Bearer " + $token)}}}}')"
else
    mcp_json="$(jq -n --arg url "${mcp_endpoint}" \
        '{mcpServers:{homeassistant:{type:"http",url:$url}}}')"
fi
mcp_wanted="$(printf '%s' "${mcp_json}" | jq -S .)"

# --- Propriété du fichier ----------------------------------------------------
mcp_owned=0
if [[ -f "${mcp_state}" ]] \
    && [[ "$(jq -S . "${mcp_state}" 2>/dev/null)" == "${mcp_wanted}" ]]; then
    mcp_owned=1
elif [[ -f "${mcp_dst}" ]] && jq -e '
    (keys == ["mcpServers"])
    and (.mcpServers | type == "object")
    and ((.mcpServers | keys) == ["homeassistant"])
    and (.mcpServers.homeassistant | type == "object")
    and (((.mcpServers.homeassistant | keys) == ["type", "url"])
         or ((.mcpServers.homeassistant | keys) == ["headers", "type", "url"]))
    and (.mcpServers.homeassistant.type == "http")
    and ((.mcpServers.homeassistant.headers // {}) |
         if . == {} then true
         else (keys == ["Authorization"])
              and (.Authorization == "Bearer $HOME_ASSISTANT_TOKEN"
                   or .Authorization == "Bearer $MCP_TOKEN")
         end)
' "${mcp_dst}" >/dev/null 2>&1; then
    # Fichier écrit par une version antérieure (aucune empreinte enregistrée) :
    # sa forme ne peut venir que de cet add-on, on le reprend en main.
    mcp_owned=1
    log_info "${mcp_dst} vient d'une version antérieure de l'add-on : repris en main"
fi

mcp_current_url="$(jq -r '.mcpServers.homeassistant.url // empty' "${mcp_dst}" 2>/dev/null)"

# --- Décision ----------------------------------------------------------------
if mcp_reachable "${mcp_endpoint}" "${probe_token}"; then
    mkdir -p "$(dirname "${mcp_dst}")"
    if [[ ! -e "${mcp_dst}" ]]; then
        printf '%s\n' "${mcp_json}" > "${mcp_dst}"
        chmod 644 "${mcp_dst}"
        printf '%s\n' "${mcp_wanted}" > "${mcp_state}"
        log_info "Outils MCP activés : ${mcp_endpoint} (${mcp_dst})"
    elif [[ "$(jq -S . "${mcp_dst}" 2>/dev/null)" == "${mcp_wanted}" ]]; then
        printf '%s\n' "${mcp_wanted}" > "${mcp_state}"
        log_info "Outils MCP déjà configurés : ${mcp_endpoint}"
    elif [[ "${mcp_owned}" == '1' ]]; then
        mkdir -p "${mcp_backup_dir}"
        backup="${mcp_backup_dir}/mcp.json.$(date +%Y%m%d-%H%M%S)"
        cp "${mcp_dst}" "${backup}"
        printf '%s\n' "${mcp_json}" > "${mcp_dst}"
        chmod 644 "${mcp_dst}"
        printf '%s\n' "${mcp_wanted}" > "${mcp_state}"
        log_info "Outils MCP mis à jour : ${mcp_current_url:-?} -> ${mcp_endpoint} (sauvegarde : ${backup})"
    else
        if [[ -n "${mcp_current_url}" && "${mcp_current_url}" == "${mcp_endpoint}" ]]; then
            log_warning "${mcp_dst} personnalisé : laissé intact (il ajoute d'autres serveurs ou clés)"
        else
            log_warning "${mcp_dst} personnalisé : laissé intact, il pointe vers ${mcp_current_url:-?} au lieu de ${mcp_endpoint}"
        fi
        log_warning "Pour le régénérer : supprimez ${mcp_dst} puis redémarrez l'add-on"
    fi
else
    case "${mcp_probe_reason}" in
        'HTTP 401' | 'HTTP 403')
            log_warning "Serveur MCP ${mcp_endpoint} : ${mcp_probe_reason} — jeton refusé ou absent (option mcp_token)"
            ;;
        *)
            log_warning "Serveur MCP injoignable (${mcp_endpoint}) : ${mcp_probe_reason} — l'agent garde l'API REST"
            ;;
    esac
    if [[ -n "${mcp_current_url}" && "${mcp_current_url}" != "${mcp_endpoint}" ]]; then
        log_warning "${mcp_dst} pointe encore vers ${mcp_current_url} ; corrigez mcp_url ou supprimez ce fichier"
    fi
fi

exit 0
