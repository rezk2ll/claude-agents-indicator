<div align="center">

<img src="docs/logo.svg" width="96" height="96" alt="">

# Claude Agents Indicator

See which Claude Code session is waiting on you, from the elementary OS panel.

[![elementary OS 8](https://img.shields.io/badge/elementary%20OS-8-64baff?logo=elementary&logoColor=white)](https://elementary.io)
[![Pantheon](https://img.shields.io/badge/desktop-Pantheon-3689e6)](https://github.com/elementary)
[![PPA](https://img.shields.io/badge/PPA-k2ll33d2-e95420?logo=ubuntu&logoColor=white)](https://launchpad.net/~k2ll33d2/+archive/ubuntu/claude-agents-indicator)
[![Release](https://img.shields.io/github/v/release/rezk2ll/claude-agents-indicator)](https://github.com/rezk2ll/claude-agents-indicator/releases/latest)
[![Build](https://github.com/rezk2ll/claude-agents-indicator/actions/workflows/build.yml/badge.svg)](https://github.com/rezk2ll/claude-agents-indicator/actions/workflows/build.yml)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue)](LICENSE)

![Screenshot](docs/screenshot.png)

</div>

A Wingpanel indicator that lists your live Claude Code sessions and tells you when one is waiting on you. You find out right away, not ten minutes later in some background tab.

Unofficial. Not affiliated with Anthropic.

## Features

- Every live session in one list, interactive tabs and background agents alike, grouped into Needs You, Your Turn and Working.
- Each row shows the conversation title, the project, and how long the session has been waiting.
- When a session needs you, the panel icon and the Terminal icon in the dock get a badge, and a notification pops up. It closes itself once you answer.
- Click a session, or its notification, to jump to its Terminal tab. Background sessions open in a new window with `claude attach`.
- 5-hour and weekly usage bars with their reset times, if cctop is installed.

## Install

From the [PPA](https://launchpad.net/~k2ll33d2/+archive/ubuntu/claude-agents-indicator), so updates arrive with your system updates:

```sh
sudo add-apt-repository ppa:k2ll33d2/claude-agents-indicator
sudo apt install claude-agents-indicator
killall io.elementary.wingpanel
```

The panel restarts on its own.

Or grab the `.deb` from the [latest release](https://github.com/rezk2ll/claude-agents-indicator/releases/latest):

```sh
sudo apt install ./claude-agents-indicator_*.deb
```

## Requirements

- elementary OS 8, or another distro running the Pantheon desktop (Wingpanel, Gala, elementary Terminal). Only elementary OS 8 is tested.
- Claude Code with agent view (`claude agents --json`).
- Optional: [cctop](https://github.com/tomstagl/cctop) as your status line, for the usage bars.

## Build from source

```sh
sudo apt install valac meson libwingpanel-dev libjson-glib-dev libgtk-3-dev libgee-0.8-dev
meson setup build --prefix=/usr
ninja -C build
sudo ninja -C build install
killall io.elementary.wingpanel
```

## How it works

- Sessions come from `claude agents --json`, polled every 3 seconds.
- Titles and last prompts are read from the session transcripts in `~/.claude/projects`.
- Terminal sets `PANTHEON_TERMINAL_ID` in each tab. The indicator reads it from the session's process and asks Terminal to select that tab.
- Usage comes from the `rate_limits` field Claude Code passes to the status line. cctop saves it under `~/.cctop/status`.

## License

[GPL-3.0-or-later](LICENSE)

## Contributing

Bug reports and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).
