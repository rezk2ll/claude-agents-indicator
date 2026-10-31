#!/bin/bash
# Runs the installed tray app inside a real xfce4-panel on Xvfb, opens its menu and saves screenshots.
# Needs xfce4-panel, xfwm4, Xvfb, xdotool, imagemagick and librsvg2-common. Usage: tests/tray-xfce.sh OUTPUT_DIR
set -euo pipefail

out=$(realpath "$1")
tests=$(dirname "$(realpath "$0")")
work=$(mktemp -d)
trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$work"' EXIT
mkdir -p "$out" "$work/.claude/projects"

Xvfb :96 -screen 0 1024x400x24 >/dev/null 2>&1 &
sleep 1
export DISPLAY=:96 PATH="$tests/fake:$PATH" HOME="$work"

dbus-run-session -- bash -c '
    set -euo pipefail
    xfwm4 >/dev/null 2>&1 &
    xfce4-panel >/dev/null 2>&1 &
    sleep 4
    claude-agents-tray >/dev/null 2>&1 &
    sleep 6
    import -window root "$1/panel.png"
    # Find the icon by its orange in the top panel, then click it.
    pos=$(convert "$1/panel.png" -crop 1024x40+0+0 txt:- | grep -iE "#D9775[0-9A-F]" | head -1 | cut -d: -f1)
    [ -n "$pos" ] || { echo "FAIL: tray icon not shown in the panel"; exit 1; }
    xdotool mousemove "${pos%,*}" "${pos#*,}" click 1
    sleep 2
    import -window root "$1/menu.png"
    changed=$(compare -metric AE "$1/panel.png" "$1/menu.png" null: 2>&1 || true)
    [ "${changed%% *}" -gt 5000 ] || { echo "FAIL: the menu did not open ($changed pixels changed)"; exit 1; }
' _ "$out"
echo "PASS: screenshots in $out"
