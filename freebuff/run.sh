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

# --- Serveurs MCP (facultatifs) ----------------------------------------------
# mcp-config.sh écrit /local_apps/.agents/mcp.json (format `mcpServers`) pour que
# la CLI expose les outils MCP de Home Assistant (tableaux de bord, fichiers YAML
# avec sauvegarde, `check_config`, traces, statistiques) et, si vous l'activez,
# ceux d'un add-on n8n (lecture et édition de workflows). Deux entrées au plus,
# chacune avec sa bascule : `ha_mcp_*` et `n8n_mcp_*`. Le fichier suit les
# options, n'est écrit que pour les serveurs qui répondent, et reste intact s'il
# a été personnalisé ; l'API REST demeure la voie de repli.
if ! bash /usr/local/share/freebuff/mcp-config.sh; then
    log_warning "Configuration MCP non appliquée : l'agent garde l'API REST"
fi

# `mcp-config.sh` tourne dans un sous-shell : son export ne remonte pas jusqu'ici.
# On exporte donc les jetons MCP dans le shell dont hérite le terminal, pour que
# les en-têtes `Bearer $HA_MCP_TOKEN` et `Bearer $N8N_MCP_TOKEN` écrits dans
# .agents/mcp.json soient résolus. Le jeton longue durée de Home Assistant reste
# `$HOME_ASSISTANT_TOKEN`, exporté plus haut.
#
# Le repli sur l'ancienne option `mcp_token` reproduit exactement celui de
# `mcp-config.sh` : tant que la migration n'est pas faite, le fichier MCP
# référence `$HA_MCP_TOKEN` alors que `ha_mcp_token` est vide. Sans ce repli, la
# variable n'était jamais exportée et l'en-tête `Authorization` partait sans
# jeton, donc refusé côté serveur, sans rien dans le journal.
ha_mcp_url_opt="$(config_value 'ha_mcp_url')"
ha_mcp_token_opt="$(config_value 'ha_mcp_token')"
if [[ -z "${ha_mcp_url_opt}" && -z "${ha_mcp_token_opt}" ]]; then
    ha_mcp_token_opt="$(config_value 'mcp_token')"
fi
if [[ -n "${ha_mcp_token_opt}" ]]; then
    export HA_MCP_TOKEN="${ha_mcp_token_opt}"
    log_info "Jeton MCP Home Assistant chargé pour le terminal (ha_mcp_token)"
fi
n8n_mcp_token_opt="$(config_value 'n8n_mcp_token')"
if [[ -n "${n8n_mcp_token_opt}" ]]; then
    export N8N_MCP_TOKEN="${n8n_mcp_token_opt}"
    log_info "Jeton MCP n8n chargé pour le terminal (n8n_mcp_token)"
fi

# Empreinte d'un jeton pour le journal : longueur et émetteur du JWT, jamais la
# valeur. Le jeton longue durée de Home Assistant porte l'identifiant de
# l'instance dans `iss`, une clé API n8n porte `n8n`. La page de configuration
# masque les champs `password` : après un enregistrement, c'est le seul contrôle
# possible, et il montre tout de suite une valeur collée au mauvais endroit.
token_fingerprint() {
    local token="$1" payload pad issuer
    if [[ "${token}" != *.*.* ]]; then
        printf '%s caractères (jeton opaque)' "${#token}"
        return 0
    fi
    payload="${token#*.}"
    payload="${payload%%.*}"
    if [[ -n "${payload}" ]]; then
        pad=$(( (4 - ${#payload} % 4) % 4 ))
        payload="$(printf '%s' "${payload}" | tr '_-' '/+' || true)"
        if [[ "${pad}" -ne 0 ]]; then
            payload="${payload}$(printf '=%.0s' $(seq 1 "${pad}"))"
        fi
        issuer="$(printf '%s' "${payload}" | base64 -d 2>/dev/null | jq -r '.iss // empty' 2>/dev/null || true)"
    fi
    printf '%s caractères (iss %s)' "${#token}" "${issuer:-illisible}"
}

mcp_fingerprints=''
if [[ -n "${ha_mcp_token_opt}" ]]; then
    mcp_fingerprints="ha_mcp_token=$(token_fingerprint "${ha_mcp_token_opt}")"
fi
if [[ -n "${n8n_mcp_token_opt}" ]]; then
    mcp_fingerprints="${mcp_fingerprints:+${mcp_fingerprints}, }n8n_mcp_token=$(token_fingerprint "${n8n_mcp_token_opt}")"
fi
if [[ -n "${mcp_fingerprints}" ]]; then
    log_info "Empreinte des jetons MCP : ${mcp_fingerprints}"
fi

# Un jeton Home Assistant collé dans `n8n_mcp_token` a la même forme qu'une clé
# n8n : n8n répond `401 unknown-issuer` et rien ne l'explique, puisque les champs
# `password` sont masqués. On le dit au démarrage plutôt que de laisser chercher.
if [[ -n "${n8n_mcp_token_opt}" ]] \
    && { [[ "${n8n_mcp_token_opt}" == "${HOME_ASSISTANT_TOKEN:-}" ]] \
         || [[ "${n8n_mcp_token_opt}" == "${ha_mcp_token_opt}" ]]; }; then
    log_warning "n8n_mcp_token est identique au jeton Home Assistant : n8n attend sa propre clé API et refuse celui-ci (401 unknown-issuer)"
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

# Raccourcis et rappel affichés à l'ouverture de chaque terminal, en français
# puis en anglais (les commandes sont les mêmes dans les deux langues).
# Le fichier est réécrit à chaque démarrage pour suivre les mises à jour de l'add-on.
cat > /etc/profile.d/00-freebuff.sh <<'PROFILE'
# `bash -l` (tmux) lit /etc/profile, donc ce fichier : les alias et la fonction
# ci-dessous n'existent que dans les shells interactifs.
case "$-" in
    *i*)
        # `fr` : lancer l'agent dans le dossier courant. `--trust-agents` charge
        # .agents/ (dont le mcp.json écrit par l'add-on) sans poser la question
        # à chaque démarrage.
        alias fr='freebuff --trust-agents'

        # Arrêt propre de l'add-on depuis le terminal : même effet que le bouton
        # « Arrêter », sans repasser par Home Assistant. Le Supervisor envoie
        # SIGTERM au conteneur et run.sh sort avec 0 (pas d'état d'erreur).
        freebuff_stop_addon() {
            printf "Arret de l'add-on... / Stopping the add-on...\n"
            curl -s -o /dev/null -X POST \
                -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
                'http://supervisor/addons/self/stop' || true
        }
        alias ex='freebuff_stop_addon'

        # --- Journaux --------------------------------------------------------
        # L'API Supervisor rend les journaux en texte brut. `apps` liste les
        # add-ons installes ; `applog <slug>` lit celui d'un add-on et
        # `applog core|supervisor|host` ceux de Home Assistant, du Supervisor et
        # de l'hote. Le role `manager` (voir config.yaml) est necessaire : sans
        # lui le Supervisor repond 403, ce que la fonction affiche au lieu de
        # laisser un silence.
        apps() {
            local json
            json="$(curl -sS -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
                http://supervisor/addons)" || return 1
            if ! printf '%s' "${json}" | jq -e '.result == "ok"' >/dev/null 2>&1; then
                printf 'Liste refusee : %s\n' "$(printf '%s' "${json}" | head -c 200)" >&2
                return 1
            fi
            printf '%s' "${json}" \
                | jq -r '.data.addons[] | .slug + "\t" + .name + (if .state == "started" then "" else " (" + .state + ")" end)' \
                | awk -F'\t' '{ printf "%-34s %s\n", $1, $2 }'
        }

        applog() {
            local target="${1:-}" lines="${2:-200}" path file status
            case "${target}" in
                ''|list)
                    printf 'Usage : applog <slug|core|supervisor|host> [lignes]\n'
                    printf 'Add-ons installes :\n'
                    apps
                    return 0
                    ;;
                core|supervisor|host) path="/${target}/logs" ;;
                *) path="/addons/${target}/logs" ;;
            esac
            file="$(mktemp)"
            status="$(curl -sS -o "${file}" -w '%{http_code}' \
                -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
                "http://supervisor${path}")" || true
            if [[ "${status}" != '200' ]]; then
                printf 'Refuse (HTTP %s) : %s\n' "${status}" "$(head -c 200 "${file}")" >&2
                rm -f "${file}"
                return 1
            fi
            tail -n "${lines}" "${file}"
            rm -f "${file}"
        }
        ;;
esac

echo
echo "  Freebuff - Home Assistant"
echo "  Première utilisation :  freebuff login"
echo "  First run :             freebuff login"
echo "  Lancer l'agent :        fr      (= freebuff --trust-agents)"
echo "  Start the agent :       fr      (= freebuff --trust-agents)"
echo "  Arreter l'add-on :      ex      (= arret propre)"
echo "  Stop the add-on :       ex      (= clean stop)"
echo "  Coller du texte :       bouton Coller en haut a droite (telephone)"
echo "  Paste text :            Paste button, top right (phone)"
echo "  Add-ons locaux : /local_apps     Configuration HA : /homeassistant"
echo "  Local add-ons :  /local_apps     HA configuration : /homeassistant"
echo "  Garde-fous agent : /local_apps/AGENTS.md (lecture obligatoire)"
echo "  Agent guardrails : /local_apps/AGENTS.md (required reading)"
echo "  Outils MCP : /local_apps/.agents/mcp.json (sinon API REST)"
echo "  MCP tools :  /local_apps/.agents/mcp.json (else REST API)"
echo "  Journaux :              applog <slug|core|supervisor|host>"
echo "  Logs :                  applog <slug|core|supervisor|host>"
echo "  Add-ons installes :     apps"
echo "  Installed add-ons :     apps"
echo "  Valider la config HA / Validate HA config :"
echo "                          curl -s -H \"Authorization: Bearer \$HA_TOKEN\" \\"
echo "                            -H 'Content-Type: application/json' -d '{}' \\"
echo "                            \"\$HA_URL/api/services/homeassistant/check_config\""
echo
PROFILE

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

# --- Arrêt propre ------------------------------------------------------------
# Le Supervisor arrête un add-on en envoyant SIGTERM au PID 1, c'est-à-dire à ce
# script. En PID 1, le noyau ne livre pas SIGTERM (ni SIGINT) à un processus qui
# n'a pas de gestionnaire : bash survit au signal, ttyd ne reçoit rien, et le
# conteneur est tué au bout du délai de grâce (code 137) — l'onglet Informations
# présente alors l'arrêt comme une erreur. Deux pièces sont donc nécessaires :
# une trappe, qui rend le signal livrable, et ttyd en arrière-plan, une trappe
# attendant la fin d'un enfant au premier plan. Le script sort ensuite avec 0
# au lieu du 143 de SIGTERM.
ttyd_pid=''
shutdown_requested='no'
on_stop_signal() {
    shutdown_requested='yes'
    if [[ -n "${ttyd_pid}" ]]; then
        kill -TERM "${ttyd_pid}" 2>/dev/null || true
    fi
}
trap on_stop_signal TERM INT

ttyd "${ttyd_args[@]}" tmux -u new -A -s freebuff bash -l &
ttyd_pid=$!
log_info "ttyd démarré (PID ${ttyd_pid})"

ttyd_status=0
while :; do
    # `wait` est interrompu par la trappe : on reboucle tant que ttyd vit.
    wait "${ttyd_pid}" || ttyd_status=$?
    kill -0 "${ttyd_pid}" 2>/dev/null || break
done
ttyd_pid=''

if [[ "${shutdown_requested}" == 'yes' ]]; then
    log_info "Arrêt demandé : terminal fermé, sortie propre"
    exit 0
fi

if [[ "${ttyd_status}" -ne 0 ]]; then
    log_error "ttyd s'est arrêté avec le code ${ttyd_status}"
fi
exit "${ttyd_status}"
