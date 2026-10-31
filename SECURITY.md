# Security

Both front ends run as your user: the indicator inside Wingpanel, the tray app as its own process. They run `claude agents --json` and read the transcripts in `~/.claude/projects`, `~/.cctop/status` and the environment of each session's process. The indicator uses the session D-Bus to reach Gala, elementary Terminal and the notification server. The tray app uses it to reach the tray and the notification server, and runs `tmux`, `kitty` or `wezterm` to raise a session's tab. Neither makes network requests.

If you find a security issue, report it privately through [GitHub security advisories](https://github.com/rezk2ll/claude-agents-indicator/security/advisories/new) instead of a public issue.

Only the latest release is supported.
