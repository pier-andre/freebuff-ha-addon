# Add-on Freebuff : terminal web (ttyd) avec la CLI Freebuff.
# Base Debian (glibc) : le binaire natif de Freebuff n'est pas prévu pour Alpine/musl.
ARG BUILD_FROM=ghcr.io/home-assistant/base-debian:bookworm

# ttyd n'est pas disponible dans les dépôts Debian Bookworm. Le compiler depuis
# une version publiée évite de dépendre d'un paquet absent.
FROM ${BUILD_FROM} AS ttyd-builder
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        git \
        libjson-c-dev \
        libwebsockets-dev \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch 1.7.7 https://github.com/tsl0922/ttyd.git /src/ttyd \
    && cmake -S /src/ttyd -B /src/ttyd/build -DCMAKE_BUILD_TYPE=Release \
    && cmake --build /src/ttyd/build --parallel \
    && cmake --install /src/ttyd/build

FROM ${BUILD_FROM}

ARG BUILD_ARCH
ARG BUILD_VERSION
ARG NODE_VERSION=26.13.0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV FREEBUFF_CONFIG_DIR=/data/freebuff \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# libatomic1 : depuis Node.js 25, les binaires Linux officiels en dépendent.
# Sans ce paquet, `node` ne démarre pas ("libatomic.so.1: cannot open shared object file").
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        jq \
        libatomic1 \
        less \
        nano \
        libjson-c5 \
        libuv1 \
        libwebsockets17 \
        libwebsockets-evlib-uv \
        openssh-client \
        procps \
        tmux \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Node.js : le lanceur npm de Freebuff télécharge ensuite le binaire natif de la bonne architecture.
RUN set -eux; \
    case "${BUILD_ARCH}" in \
        amd64) node_arch="x64" ;; \
        aarch64) node_arch="arm64" ;; \
        *) echo "Architecture non supportée: ${BUILD_ARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" -o /tmp/node.tar.xz; \
    tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 --no-same-owner; \
    rm -f /tmp/node.tar.xz; \
    node --version; \
    npm --version

# CLI Freebuff (rebuild de l'add-on = mise à jour)
RUN npm install --global freebuff@latest \
    && freebuff --version

COPY run.sh /run.sh
# Configuration MCP écrite au démarrage (fichier géré, suit les options).
COPY mcp-config.sh /usr/local/share/freebuff/mcp-config.sh
# Contexte et garde-fous de l'agent, installés dans /local_apps au démarrage.
COPY AGENTS.md /usr/local/share/freebuff/AGENTS.md
COPY --from=ttyd-builder /usr/local/bin/ttyd /usr/local/bin/ttyd
RUN chmod a+x /run.sh /usr/local/share/freebuff/mcp-config.sh

# tmux : la molette (y compris les crans synthétisés par le défilement tactile
# de la page web) entre en mode copie, avec assez d'historique pour remonter une
# longue conversation de l'agent.
COPY tmux.conf /etc/tmux.conf

# Page web de ttyd + correctifs mobiles. La page de ttyd 1.7.7 est autonome
# (xterm.js y est inliné) : on récupère donc la page exactement servie par le
# binaire compilé, on y insère `mobile.html` avant </head>, et l'add-on sert le
# résultat avec `--index`. Rien n'est copié de ttyd dans le dépôt, et une mise à
# jour de ttyd régénère la page au build suivant.
COPY mobile.html build-index.mjs /usr/local/share/freebuff/
RUN set -eux; \
    ttyd --port 7681 --writable --once sleep 30 >/dev/null 2>&1 & \
    ttyd_pid=$!; \
    for _ in $(seq 1 100); do \
        if curl -fsS http://127.0.0.1:7681/ -o /tmp/ttyd-index.html; then break; fi; \
        sleep 0.1; \
    done; \
    kill "${ttyd_pid}" 2>/dev/null || true; \
    test -s /tmp/ttyd-index.html; \
    node /usr/local/share/freebuff/build-index.mjs \
        /tmp/ttyd-index.html \
        /usr/local/share/freebuff/mobile.html \
        /usr/local/share/freebuff/index.html; \
    rm -f /tmp/ttyd-index.html; \
    ls -l /usr/local/share/freebuff/index.html

# L'image Home Assistant démarre s6-overlay ; ici c'est run.sh qui lance ttyd (init: false).
ENTRYPOINT []
CMD [ "/run.sh" ]
