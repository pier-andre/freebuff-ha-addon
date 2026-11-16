# Freebuff for Home Assistant

[Français](README.md) · **English**

An add-on that provides the [Freebuff](https://freebuff.com/cli) CLI in a web terminal inside Home
Assistant, and can hold a dedicated token for the local Home Assistant API.

[![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fpier-andre%2Ffreebuff-ha-addon) [![Open your Home Assistant instance and show the dashboard of an add-on.](https://my.home-assistant.io/badges/supervisor_app.svg)](https://my.home-assistant.io/redirect/supervisor_app/?app=dc337d8e_freebuff&repository_url=https%3A%2F%2Fgithub.com%2Fpier-andre%2Ffreebuff-ha-addon)

## What the add-on does

- installs Node.js + `freebuff` (the official CLI, always the latest version at build time);
- opens a web terminal (ttyd + tmux) inside Home Assistant through Ingress;
- mounts `/local_apps` (your local add-ons) and `/homeassistant` (your HA configuration);
- keeps the Freebuff session in `/data`, so you do not log in again after a restart;
- gives the agent access to the Home Assistant API: configurable address and port, a long-lived
  token in a secret field (or the Supervisor proxy as a fallback);
- installs `/local_apps/AGENTS.md`, the agent's context and guardrails: non-destructive changes,
  backup before writing, configuration validation before going further;
- adds the Home Assistant MCP tools when an MCP server is available — the built-in integration
  (`/api/mcp`), an equivalent custom component, or the HA-MCP add-on from the Marketplace through
  `mcp_url` — to edit dashboards, YAML files with a backup, and traces; the REST API remains the
  fallback;
- starts the agent with one word (`fr`, i.e. `freebuff --trust-agents`) and stops the add-on from
  the terminal (`ex`); both stop cleanly, with no error state in the **Log** tab;
- adapts the terminal to a phone: finger scrolling of the conversation (swipe translated into wheel
  steps for tmux, 50,000-line history), a `viewport` tag, an input field that works with predictive
  keyboards (SwiftKey, Gboard), a height tied to the visual viewport so the input line stays above
  the keyboard, and a **Paste** button that saves typing a text character by character;
- speaks **French and English**: the terminal banner repeats every line in both languages, and the
  mobile page controls (**Coller**/**Paste**, **Annuler**/**Cancel**, **Envoyer**/**Send**) follow
  the Home Assistant interface language, then the browser's.

## Installation

The add-on lives in the `freebuff/` folder of this repository, and its name is its identifier:
`freebuff/config.yaml`, `freebuff/Dockerfile`, `freebuff/run.sh`, `freebuff/DOCS.md`,
`freebuff/CHANGELOG.md` and `freebuff/AGENTS.md` must stay together. `repository.yaml` and
`renovate.json` stay at the root of the repository.

1. In Home Assistant: **Settings → Add-ons → Add-on Store** → ⋮ menu → **Repositories** → paste
   `https://github.com/pier-andre/freebuff-ha-addon` → **Add**.
   The repository must stay **public**: the store clones it without credentials.

2. The "Freebuff CLI" add-on appears in the store. **Install**, then **Start**.
   (Allow several minutes for the first installation: Node.js + Freebuff are downloaded.)

3. Home Assistant installs the add-on under the name `dc337d8e_freebuff`: the `dc337d8e` prefix is
   the start of the SHA-1 of the repository URL, computed from the URL as entered (without a
   trailing `/` or `.git`, otherwise the prefix changes). Its data therefore lives in
   `/data/apps/data/dc337d8e_freebuff`. If you are coming from a local copy installed from
   `/addons` (identifier `local_freebuff`), move `/data/apps/data/local_freebuff` to
   `/data/apps/data/dc337d8e_freebuff` before starting the new installation, otherwise you start
   from an empty `/data` (conversation history and Git configuration included).

### Updates

The `renovate.json` file at the root of the repository is read by the
[Renovate](https://github.com/pier-andre/renovate-ha-addon) add-on: a dependency update arrives as a
pull request with the `version:` in `freebuff/config.yaml` bumped and a line added to
`freebuff/CHANGELOG.md`. Once merged, the store offers it on the next "Check for updates".

4. Open **Freebuff** in the sidebar, then type `freebuff login` and follow the link shown on your
   phone or computer. Go back to the terminal: you are logged in.

## Usage

```bash
cd /local_apps/my-add-on       # an add-on you are developing
fr                             # = freebuff --trust-agents: the agent starts
ex                             # stops the add-on cleanly from the terminal
```

For a regular GitHub repository, clone it into `/share` (or `/local_apps`) and run `freebuff` in it.

### How Freebuff stays free

Freebuff is funded by **advertising**, and it says so: ad banners appear in the CLI — so, here, in
the web terminal — **and** in Freebuff's web chat interface. That is what makes the service possible
without a subscription. Expect a slightly more talkative terminal than usual: those slots change
nothing about how the agent works or about the files it reads and writes, and they require no action
from you.

To support the add-on, create your account from the maintainer's referral link:

<https://freebuff.com/?ref=ref-094f56be-de2b-4d31-aa7e-6e3f6c49bc62&via=rewards_link>

The account is free either way; the link only tells them you came from here.

### Home Assistant access

Store a long-lived token from a dedicated Home Assistant account in the secret
`home_assistant_token` option. The terminal receives it in `HOME_ASSISTANT_TOKEN` and `HA_TOKEN`,
with `HA_URL` built from `home_assistant_url` and `home_assistant_port` (default
`http://homeassistant:8123`). Without a token, the add-on falls back to the Supervisor proxy. Keep
the account's permissions to the minimum.

### Agent guardrails

`/local_apps/AGENTS.md` reminds the agent that it works inside a Home Assistant add-on and requires:
non-destructive changes, a backup before writing, configuration validation
(`homeassistant.check_config`, the equivalent of `ha core check`) before going further, immediate
restore if it fails, and no restarting Home Assistant.

## Known limitations

- The Freebuff CLI is interactive and needs the web terminal.
- Architecture-dependent: `amd64` works; `aarch64` (Raspberry Pi, HA Green/Yellow) depends on a Linux
  ARM binary existing on Freebuff's side. If the build fails on ARM, remove `aarch64` from the
  `arch` list in `config.yaml`.
- Freebuff is free but funded by **advertising**: banners appear in the CLI and in the web chat
  interface (see [How Freebuff stays free](#how-freebuff-stays-free)).
- This add-on is not maintained by Home Assistant or by Freebuff: it is a community wrapper.
