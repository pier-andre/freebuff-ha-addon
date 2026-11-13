#!/usr/bin/env bash
# Add-on Freebuff : lance un terminal web (Ingress) avec la CLI Freebuff.
set -e

OPTIONS_FILE=/data/options.json
if [[ ! -r "${OPTIONS_FILE}" ]]; then
    printf 'Erreur: fichier de configuration absent: %s\n' "${OPTIONS_FILE}" >&2
    exit 1
fi

config_value() {
    jq -r --arg key "$1" '.[$key] // empty' "${OPTIONS_FILE}"
}

config_has_value() {
    [[ -n "$(config_value "$1")" ]]
}

log_info() { printf 'INFO: %s\n' "$*"; }
log_warning() { printf 'AVERTISSEMENT: %s\n' "$*" >&2; }
log_error() { printf 'ERREUR: %s\n' "$*" >&2; }

log_info "Démarrage du terminal Freebuff (Ingress, port 8099)"

# HOME doit être défini AVANT tout 'git config --global' : sinon l'identité et le
# helper d'identifiants sont écrits dans /root/.gitconfig, que les terminaux de
# l'agent (HOME=/data/freebuff) n'utilisent pas.
export HOME=/data/freebuff
# 'git config --global' écrit dans $HOME : le dossier doit exister avant,
# sinon un /data neuf fait échouer le script (could not lock .gitconfig).
umask 077
mkdir -p "${HOME}/.config/manicode"

# Identité Git, utilisée par les commits de l'agent
if config_has_value 'git_name'; then
    git config --global user.name "$(config_value 'git_name')"
fi
if config_has_value 'git_email'; then
    git config --global user.email "$(config_value 'git_email')"
fi

# Jeton GitHub (facultatif) : fournit les identifiants à git pour push/pull.
# Le jeton reste dans les options de l'add-on, il n'est jamais écrit sur le disque.
github_credential_helper='!f() { echo username=x-access-token; echo "password=${GH_TOKEN}"; }; f'
if config_has_value 'github_token'; then
    export GH_TOKEN="$(config_value 'github_token')"
    export GITHUB_TOKEN="${GH_TOKEN}"
    git config --global credential.https://github.com.helper "${github_credential_helper}"
    log_info "Jeton GitHub chargé pour les commandes git"
else
    # Évite de garder un helper pointant vers un jeton vide après retrait de l'option.
    git config --global --unset credential.https://github.com.helper 2>/dev/null || true
fi

# Paquets supplémentaires demandés dans les options
mapfile -t extra_packages < <(jq -r '.extra_packages[]? // empty' "${OPTIONS_FILE}")
for package in "${extra_packages[@]}"; do
    log_info "Installation du paquet ${package}..."
    if ! apt-get update >/dev/null 2>&1 \
        || ! apt-get install -y --no-install-recommends "${package}" >/dev/null 2>&1; then
        log_warning "Impossible d'installer ${package}"
    fi
done

# Identifiants de la CLI sous /data (HOME défini plus haut).
export FREEBUFF_CONFIG_DIR="${HOME}"
umask 077
mkdir -p "${HOME}/.config/manicode"
credentials_file="${HOME}/.config/manicode/credentials.json"
if [[ ! -s "${credentials_file}" ]]; then
    for legacy_credentials in /data/freebuff/credentials.json /root/.config/manicode/credentials.json; do
        if [[ -s "${legacy_credentials}" ]]; then
            cp "${legacy_credentials}" "${credentials_file}"
            chmod 600 "${credentials_file}"
            break
        fi
    done
fi

# --- Accès à l'API Home Assistant -------------------------------------------
# Deux modes, dans cet ordre :
#   1. jeton longue durée d'un compte HA dédié (`home_assistant_token`, champ
#      secret) : rien n'est écrit sur le disque, le jeton ne vit que dans
#      l'environnement du terminal ;
#   2. à défaut, le proxy Supervisor (`http://supervisor/core`, permission
#      `homeassistant_api`) : le jeton est éphémère et fourni par le Supervisor.
# L'adresse est configurable (`home_assistant_url`, `home_assistant_port`) pour
# les instances derrière un reverse proxy ou en HTTPS.
ha_port="$(config_value 'home_assistant_port')"
[[ -n "${ha_port}" ]] || ha_port=8123

home_assistant_url() {
    local url
    url="$(config_value 'home_assistant_url')"
    if [[ -z "${url}" ]]; then
        printf 'http://homeassistant:%s' "${ha_port}"
        return
    fi
    [[ "${url}" == *"://"* ]] || url="http://${url}"
    url="${url%/}"
    # Un port explicite dans l'URL est prioritaire sur `home_assistant_port`.
    if [[ "${url}" =~ ^[A-Za-z][A-Za-z0-9+.-]*://[^/]+:[0-9]+$ ]]; then
        printf '%s' "${url}"
    else
        printf '%s:%s' "${url}" "${ha_port}"
    fi
}

export HA_PORT="${ha_port}"
if config_has_value 'home_assistant_token'; then
    export HOME_ASSISTANT_TOKEN="$(config_value 'home_assistant_token')"
    export HA_TOKEN="${HOME_ASSISTANT_TOKEN}"
    export HA_URL="$(home_assistant_url)"
    log_info "Jeton Home Assistant longue durée chargé (${HA_URL})"
else
    export HA_URL='http://supervisor/core'
    export HA_TOKEN="${SUPERVISOR_TOKEN}"
    log_info "API Home Assistant via le proxy Supervisor (${HA_URL})"
fi

# --- Serveur MCP de Home Assistant (facultatif) ------------------------------
# La CLI lit /local_apps/.agents/mcp.json (format `mcpServers`) et expose les
# outils du serveur MCP comme des outils de l'agent : tableaux de bord, fichiers
# YAML avec sauvegarde, traces d'automatisation, statistiques, recherche
# d'entités. L'API REST reste la voie de repli : si aucun serveur MCP n'est
# joignable, ce bloc n'écrit rien et l'agent travaille comme avant.
# Un seul fichier couvre les quatre montages courants :
#   * integration intégrée `mcp_server` (HA 2025.2+) : {HA_URL}/api/mcp, jeton
#     longue durée en Bearer — c'est le défaut, aucun réglage nécessaire ;
#   * composant tiers exposant /api/mcp (MCP Server (HTTP Transport)…) : même
#     adresse, même jeton, donc même défaut ;
#   * app « HA-MCP » du Marketplace (port 9583, chemin secret, sans jeton) ;
#   * hass-mcp (/api/hass_mcp) et ha-mcp-web (port 8086, /mcp) : via `mcp_url`
#     et, si le serveur en demande un, `mcp_token`.
mcp_dst=/local_apps/.agents/mcp.json
mcp_url_opt="$(config_value 'mcp_url')"
mcp_token_opt="$(config_value 'mcp_token')"
mcp_endpoint=''
mcp_header_token=''

if [[ -n "${mcp_url_opt}" ]]; then
    mcp_endpoint="${mcp_url_opt}"
    # Jeton propre à ce serveur : il reste dans l'environnement, jamais dans le
    # fichier. Sans `mcp_token`, aucun en-tête Authorization n'est envoyé — le
    # jeton Home Assistant ne doit pas partir vers un autre conteneur.
    if [[ -n "${mcp_token_opt}" ]]; then
        export MCP_TOKEN="${mcp_token_opt}"
        mcp_header_token='$MCP_TOKEN'
    fi
elif [[ -n "${HOME_ASSISTANT_TOKEN:-}" ]]; then
    # Pas de repli Supervisor ici : http://supervisor/core ne relaie pas
    # /api/mcp (502 constaté), contrairement aux routes REST classiques.
    mcp_endpoint="${HA_URL}/api/mcp"
    mcp_header_token='$HOME_ASSISTANT_TOKEN'
else
    log_info "MCP ignoré : sans jeton longue durée, l'API REST passe par le proxy Supervisor"
fi

# Poignée de main MCP : le fichier n'est écrit que si le serveur répond, pour ne
# pas laisser à la CLI un serveur mort à chaque démarrage.
mcp_reachable() {
    MCP_PROBE_URL="$1" MCP_PROBE_TOKEN="$2" node -e '
const headers = {
  "Content-Type": "application/json",
  "Accept": "application/json, text/event-stream",
}
if (process.env.MCP_PROBE_TOKEN) {
  headers.Authorization = "Bearer " + process.env.MCP_PROBE_TOKEN
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
  .then((response) => process.exit(response.ok ? 0 : 1))
  .catch(() => process.exit(1))
' 2>/dev/null
}

if [[ -n "${mcp_endpoint}" ]]; then
    if [[ "${mcp_header_token}" == '$MCP_TOKEN' ]]; then
        mcp_probe_token="${MCP_TOKEN}"
    elif [[ "${mcp_header_token}" == '$HOME_ASSISTANT_TOKEN' ]]; then
        mcp_probe_token="${HOME_ASSISTANT_TOKEN}"
    else
        mcp_probe_token=''
    fi

    if [[ -n "${mcp_header_token}" ]]; then
        mcp_json="$(jq -n --arg url "${mcp_endpoint}" --arg token "${mcp_header_token}" \
            '{mcpServers:{homeassistant:{type:"http",url:$url,headers:{Authorization:("Bearer " + $token)}}}}')"
    else
        mcp_json="$(jq -n --arg url "${mcp_endpoint}" \
            '{mcpServers:{homeassistant:{type:"http",url:$url}}}')"
    fi

    if mcp_reachable "${mcp_endpoint}" "${mcp_probe_token}"; then
        mkdir -p /local_apps/.agents
        if [[ ! -e "${mcp_dst}" ]]; then
            printf '%s\n' "${mcp_json}" > "${mcp_dst}"
            chmod 644 "${mcp_dst}"
            log_info "Outils MCP activés : ${mcp_endpoint} (${mcp_dst})"
        elif [[ "$(jq -S . "${mcp_dst}" 2>/dev/null)" == "$(printf '%s' "${mcp_json}" | jq -S .)" ]]; then
            log_info "Outils MCP déjà configurés : ${mcp_endpoint}"
        else
            log_info "${mcp_dst} personnalisé : laissé intact, MCP non reconfiguré"
        fi
    else
        log_warning "Serveur MCP injoignable (${mcp_endpoint}) : ${mcp_dst} non écrit, l'agent garde l'API REST"
    fi
fi

# Les dossiers montés appartiennent à root : évite les erreurs "dubious ownership"
git config --global --add safe.directory '*'

# Contexte et garde-fous de l'agent : réinstallés à chaque démarrage pour suivre
# les mises à jour de l'add-on, sauf si l'utilisateur a écrit son propre fichier.
agents_src=/usr/local/share/freebuff/AGENTS.md
agents_dst=/local_apps/AGENTS.md
agents_marker='<!-- freebuff-addon-guardrails -->'
if [[ -f "${agents_src}" ]]; then
    if [[ ! -e "${agents_dst}" ]] || [[ "$(head -n 1 "${agents_dst}" 2>/dev/null)" == "${agents_marker}" ]]; then
        cp "${agents_src}" "${agents_dst}"
        chmod 644 "${agents_dst}"
        log_info "Instructions de l'agent installées dans ${agents_dst}"
    else
        log_info "${agents_dst} personnalisé : garde-fous de l'add-on non installés"
    fi
fi

# Rappel affiché à l'ouverture de chaque terminal
cat > /etc/profile.d/00-freebuff.sh <<'BANNER'
echo
echo "  Freebuff - Home Assistant"
echo "  Première utilisation :  freebuff login"
echo "  Ensuite :               cd /local_apps/mon-add-on && freebuff"
echo "  Add-ons locaux : /local_apps     Configuration HA : /homeassistant"
echo "  Garde-fous agent : /local_apps/AGENTS.md (lecture obligatoire)"
echo "  Outils MCP : /local_apps/.agents/mcp.json (sinon API REST)"
echo "  Valider la config HA :  curl -s -H \"Authorization: Bearer \$HA_TOKEN\" \\"
echo "                            -H 'Content-Type: application/json' -d '{}' \\"
echo "                            \"\$HA_URL/api/services/homeassistant/check_config\""
echo
BANNER

cd /local_apps 2>/dev/null || cd /

export TTYD=1

# Page web : ttyd sert sa propre interface, dans laquelle le build a inséré les
# correctifs mobiles (viewport, défilement tactile, champ de saisie compatible
# avec les claviers à prédiction). Si le fichier manque, on garde l'interface
# d'origine plutôt que de refuser de démarrer.
ttyd_index=/usr/local/share/freebuff/index.html
ttyd_args=(--port 8099 --writable)
if [[ -s "${ttyd_index}" ]]; then
    ttyd_args+=(--index "${ttyd_index}")
    log_info "Interface web : défilement tactile et saisie mobile activés"
else
    log_warning "Interface web d'origine (${ttyd_index} absent) : correctifs mobiles inactifs"
fi

log_info "Terminal disponible dans la barre latérale : Freebuff"
ttyd "${ttyd_args[@]}" tmux -u new -A -s freebuff bash -l
