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

# Jeton longue durée Home Assistant (facultatif), disponible pour les outils CLI.
if config_has_value 'home_assistant_token'; then
    export HOME_ASSISTANT_TOKEN="$(config_value 'home_assistant_token')"
    export HA_TOKEN="${HOME_ASSISTANT_TOKEN}"
    export HA_URL='http://homeassistant:8123'
    log_info "Jeton Home Assistant local chargé"
fi

# Les dossiers montés appartiennent à root : évite les erreurs "dubious ownership"
git config --global --add safe.directory '*'

# Rappel affiché à l'ouverture de chaque terminal
cat > /etc/profile.d/00-freebuff.sh <<'BANNER'
echo
echo "  Freebuff - Home Assistant"
echo "  Première utilisation :  freebuff login"
echo "  Ensuite :               cd /local_apps/mon-add-on && freebuff"
echo "  Add-ons locaux : /local_apps     Configuration HA : /homeassistant"
echo
BANNER

cd /local_apps 2>/dev/null || cd /

export TTYD=1
log_info "Terminal disponible dans la barre latérale : Freebuff"

ttyd \
    --port 8099 \
    --writable \
    tmux -u new -A -s freebuff bash -l
