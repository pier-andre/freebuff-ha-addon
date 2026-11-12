# Add-on Freebuff : terminal web (ttyd) et proxy API Freebuff2API.
# Base Debian (glibc) : le binaire natif de Freebuff n'est pas prévu pour Alpine/musl.
ARG FREEBUFF2API_REF=main
ARG BUILD_FROM=ghcr.io/home-assistant/base-debian:bookworm
FROM golang:1.23-bookworm AS api-builder
ARG FREEBUFF2API_REF
RUN git clone --depth 1 --branch "${FREEBUFF2API_REF}" https://github.com/Quorinex/Freebuff2API.git /src
WORKDIR /src
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /Freebuff2API .

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
COPY --from=api-builder /Freebuff2API /usr/local/bin/Freebuff2API
COPY --from=ttyd-builder /usr/local/bin/ttyd /usr/local/bin/ttyd
RUN chmod a+x /run.sh

# L'image Home Assistant démarre s6-overlay ; ici c'est run.sh qui lance ttyd (init: false).
ENTRYPOINT []
CMD [ "/run.sh" ]
