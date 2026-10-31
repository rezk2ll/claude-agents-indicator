#!/bin/bash
# Starts the tray against a fake claude and a fake tray host, then checks the menu the host sees.
# Needs Xvfb, dbus-run-session and python3-gi. Usage: tests/tray-smoke.sh path/to/claude-agents-tray
set -euo pipefail

tray=$(realpath "$1")
tests=$(dirname "$(realpath "$0")")
work=$(mktemp -d)
trap 'kill $(jobs -p) 2>/dev/null || true; rm -rf "$work"' EXIT

mkdir -p "$work/home/.claude/projects"

Xvfb :97 >/dev/null 2>&1 &
sleep 1
export DISPLAY=:97 PATH="$tests/fake:$PATH" HOME="$work/home"

dbus-run-session -- bash -c '
    python3 "$1/sni-host.py" 4 > "$3/host.out" 2>&1 &
    host=$!
    sleep 1
    "$2" > "$3/tray.log" 2>&1 &
    wait $host
' _ "$tests" "$tray" "$work"

cat "$work/host.out"
expect() {
    grep -qF -- "$1" "$work/host.out" || { echo "FAIL: expected \"$1\""; cat "$work/tray.log"; exit 1; }
}
expect "Status: NeedsAttention"
expect "AttentionIconName: claude-agents-tray-attention"
expect "Title: 1 session needs you | Label: 1"
expect "Needs You"
expect "acme-api · permission prompt"
expect "nightly fix · acme-web"
expect "Open Agent View"

# claude-agents-status is built and installed next to the tray app.
status=$(dirname "$tray")/claude-agents-status
[ "$(PATH="$tests/fake:$PATH" HOME="$work/home" "$status")" = "1 need you · 1 your turn · 1 working" ] || { echo "FAIL: claude-agents-status"; exit 1; }
PATH="$tests/fake:$PATH" HOME="$work/home" "$status" --waybar | python3 -c '
import json, sys
out = json.load(sys.stdin)
assert out["text"] == "1" and out["class"] == "attention", out
assert "acme-api · permission prompt" in out["tooltip"], out'
echo PASS
