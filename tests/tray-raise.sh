#!/bin/bash
# Opens two terminals, clicks the session in the tray menu, and checks that the session's terminal came to the front.
# Usage: tests/tray-raise.sh x11|sway
#   x11:  needs Xvfb, xfwm4, xterm, xdotool, python3-gi and dbus-run-session
#   sway: needs sway, foot, a font, python3-gi and dbus-run-session
set -euo pipefail

mode=$1
tests=$(dirname "$(realpath "$0")")
work=$(mktemp -d)
trap 'kill $(jobs -p) 2>/dev/null || true; rm -rf "$work"' EXIT
mkdir -p "$work/home/.claude/projects"
export PATH="$tests/fake:$PATH" HOME="$work/home" FAKE_AGENTS_JSON="$work/agents.json" WORK="$work" TESTS="$tests"

case $mode in
    x11)
        Xvfb :94 >/dev/null 2>&1 &
        sleep 1
        export DISPLAY=:94 XDG_SESSION_TYPE=x11
        ;;
    sway)
        export XDG_RUNTIME_DIR="$work/run" WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1
        mkdir -m 700 "$XDG_RUNTIME_DIR"
        : > "$work/sway.conf"
        ;;
    *)
        echo "unknown mode $mode"
        exit 2
        ;;
esac

dbus-run-session -- bash -c '
    set -euo pipefail
    case $1 in
        x11)
            xfwm4 --compositor=off >/dev/null 2>&1 &
            sleep 2
            terminal() { xterm -e "$@" >/dev/null 2>&1 & }
            focus_pid() { xdotool getactivewindow getwindowpid; }
            focus_other() { xdotool windowactivate "$(xdotool search --onlyvisible --pid "$1" | head -1)"; }
            ;;
        sway)
            sway -c "$WORK/sway.conf" >"$WORK/sway.log" 2>&1 &
            for _ in $(seq 50); do ls "$XDG_RUNTIME_DIR"/sway-ipc.* >/dev/null 2>&1 && break; sleep 0.2; done
            export SWAYSOCK=$(ls "$XDG_RUNTIME_DIR"/sway-ipc.*) WAYLAND_DISPLAY=wayland-1
            terminal() { foot "$@" >/dev/null 2>&1 & }
            focus_pid() {
                swaymsg -t get_tree -r | python3 -c "
import json, sys
def walk(n):
    if n.get(\"focused\") and n.get(\"pid\"): print(n[\"pid\"]); return True
    return any(walk(c) for c in n.get(\"nodes\", []) + n.get(\"floating_nodes\", []))
walk(json.load(sys.stdin))"
            }
            focus_other() { swaymsg "[pid=$1] focus" >/dev/null; }
            ;;
    esac

    terminal sh -c "echo \$\$ > $WORK/session.pid; exec sleep 600"
    session_terminal=$!
    terminal sleep 600
    other_terminal=$!
    sleep 3
    printf "[{\"id\":\"r1\",\"sessionId\":\"s-r\",\"cwd\":\"/home/me/raise-me\",\"kind\":\"interactive\",\"status\":\"waiting\",\"pid\":%s}]" \
        "$(cat "$WORK/session.pid")" > "$WORK/agents.json"

    focus_other "$other_terminal"
    sleep 1
    [ "$(focus_pid)" = "$other_terminal" ] || { echo "FAIL: could not focus the other terminal first"; exit 1; }

    python3 "$TESTS/sni-host.py" 4 raise-me > "$WORK/host.out" 2>&1 &
    host=$!
    sleep 1
    claude-agents-tray > "$WORK/tray.log" 2>&1 &
    wait $host
    sleep 1
    grep -q "Clicked: True" "$WORK/host.out" || { cat "$WORK/host.out"; echo "FAIL: session not in the menu"; exit 1; }

    focused=$(focus_pid)
    if [ "$focused" != "$session_terminal" ]; then
        echo "FAIL: focused pid $focused, expected the session terminal $session_terminal"
        cat "$WORK/tray.log"
        exit 1
    fi
' _ "$mode"
echo "PASS: $mode raised the session terminal"
