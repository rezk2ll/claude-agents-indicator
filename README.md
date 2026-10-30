# Claude Agents Indicator

A Wingpanel indicator for elementary OS that tracks your Claude Code sessions. When a session is waiting on you, you see it in the panel instead of finding out ten minutes later in some background tab.

![Screenshot](docs/screenshot.png)

Unofficial. Not affiliated with Anthropic.

## What it does

- Lists every live Claude Code session, interactive tabs and background agents alike, grouped into Needs You, Your Turn and Working.
- Shows each session's conversation title, project, and how long it has been waiting.
- Badges the panel icon and the Terminal icon in the dock while a session needs you.
- Sends a notification when a session needs you or finishes, and closes it once you answer.
- Clicking a session (or its notification) jumps to its Terminal tab. Background sessions open in a new window with `claude attach`.
- Shows your 5-hour and weekly usage with reset times, if cctop is installed.

## Requirements

- elementary OS 8
- Claude Code with agent view (`claude agents --json`)
- Optional: [cctop](https://github.com/tomstagl/cctop) as your status line, for the usage bars

## Build and install

```sh
sudo apt install valac meson libwingpanel-dev libjson-glib-dev libgtk-3-dev libgee-0.8-dev
meson setup build --prefix=/usr
ninja -C build
sudo ninja -C build install
killall io.elementary.wingpanel
```

The panel comes back on its own.

## How it works

- Sessions come from `claude agents --json`, polled every 3 seconds.
- Titles and last prompts are read from the session transcripts in `~/.claude/projects`.
- Terminal sets `PANTHEON_TERMINAL_ID` in each tab. The indicator reads it from the session's process and asks Terminal to select that tab.
- Usage comes from the `rate_limits` field Claude Code passes to the status line. cctop saves it under `~/.cctop/status`.

## License

GPL-3.0-or-later
