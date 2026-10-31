# Security

The indicator runs inside Wingpanel as your user. It runs `claude agents --json`, reads the transcripts in `~/.claude/projects`, `~/.cctop/status` and the environment of each session's process, and uses the session D-Bus to reach Gala, elementary Terminal and the notification server. It makes no network requests.

If you find a security issue, report it privately through [GitHub security advisories](https://github.com/rezk2ll/claude-agents-indicator/security/advisories/new) instead of a public issue.

Only the latest release is supported.
