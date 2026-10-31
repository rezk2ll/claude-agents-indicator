#!/bin/bash
# Opens two terminals, clicks the session in the tray menu, and checks that the session's terminal came to the front.
# Usage: tests/tray-raise.sh x11|sway|kwin
#   x11:  needs Xvfb, xfwm4, xterm, xdotool, python3-gi and dbus-run-session
#   sway: needs sway, foot, a font, python3-gi and dbus-run-session
#   kwin: needs kwin_wayland, foot, a font, python3-gi and dbus-run-session
set -euo pipefail

mode=$1
tests=$(dirname "$(realpath "$0")")
work=$(mktemp -d)
trap 'kill $(jobs -p) 2>/dev/null || true; rm -rf "$work"' EXIT
mkdir -p "$work/home/.claude/projects" "$work/bin"
# Records what the tray opens in a terminal instead of opening one.
printf '#!/bin/sh\necho "$@" > "%s/opened"\n' "$work" > "$work/bin/xdg-terminal-exec"
chmod +x "$work/bin/xdg-terminal-exec"
export PATH="$work/bin:$tests/fake:$PATH" HOME="$work/home" FAKE_AGENTS_JSON="$work/agents.json" WORK="$work" TESTS="$tests"

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
    kwin)
        export XDG_RUNTIME_DIR="$work/run" XDG_CURRENT_DESKTOP=KDE
        mkdir -m 700 "$XDG_RUNTIME_DIR"
        # kwin_wayland carries file capabilities, which containers refuse to exec; a copy has none.
        cp "$(command -v kwin_wayland)" "$work/kwin_wayland"
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
        kwin)
            "$WORK/kwin_wayland" --virtual --no-lockscreen --socket wayland-9 --width 800 --height 600 >"$WORK/kwin.log" 2>&1 &
            for _ in $(seq 50); do [ -S "$XDG_RUNTIME_DIR/wayland-9" ] && break; sleep 0.2; done
            sleep 2
            export WAYLAND_DISPLAY=wayland-9
            terminal() { foot "$@" >/dev/null 2>&1 & }
            focus_pid() { python3 "$TESTS/kwin-script.py" "report (workspace.activeWindow ? workspace.activeWindow.pid : 0)"; }
            focus_other() {
                python3 "$TESTS/kwin-script.py" "workspace.activeWindow = workspace.windowList ().find (w => w.pid === $1); report (1)" >/dev/null
            }
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
    tray=$!
    wait $host
    sleep 1
    grep -q "Clicked: True" "$WORK/host.out" || { cat "$WORK/host.out"; echo "FAIL: session not in the menu"; exit 1; }

    focused=$(focus_pid)
    if [ "$focused" != "$session_terminal" ]; then
        echo "FAIL: focused pid $focused, expected the session terminal $session_terminal"
        cat "$WORK/tray.log"
        tail -20 "$WORK/kwin.log" 2>/dev/null || true
        exit 1
    fi

    # The shortcut path: a second launch with --jump goes to the waiting session too.
    focus_other "$other_terminal"
    sleep 1
    claude-agents-tray --jump
    sleep 1
    focused=$(focus_pid)
    [ "$focused" = "$session_terminal" ] || { cat "$WORK/tray.log"; echo "FAIL: --jump focused $focused"; exit 1; }
    echo "PASS: $1 --jump raised the session terminal"

    # With no tray running, --jump starts one, which jumps once it has the sessions.
    kill $tray
    wait $tray || true
    focus_other "$other_terminal"
    sleep 1
    claude-agents-tray --jump > "$WORK/tray.log" 2>&1 &
    sleep 5
    focused=$(focus_pid)
    [ "$focused" = "$session_terminal" ] || { cat "$WORK/tray.log"; echo "FAIL: cold --jump focused $focused"; exit 1; }
    echo "PASS: $1 --jump started the tray and raised the session terminal"
    [ "$1" = kwin ] || exit 0

    # A session with no window: KWin reports the miss and the tray opens the agent view instead.
    sleep 600 &
    printf "[{\"id\":\"r2\",\"sessionId\":\"s-n\",\"cwd\":\"/home/me/no-window\",\"kind\":\"interactive\",\"status\":\"waiting\",\"pid\":%s}]" \
        $! > "$WORK/agents.json"
    python3 "$TESTS/sni-host.py" 8 no-window > "$WORK/host.out" 2>&1
    sleep 1
    grep -q "Clicked: True" "$WORK/host.out" || { cat "$WORK/host.out"; echo "FAIL: windowless session not in the menu"; exit 1; }
    grep -q " agents$" "$WORK/opened" 2>/dev/null || { cat "$WORK/tray.log"; echo "FAIL: the agent view did not open"; exit 1; }
    echo "PASS: kwin fell back to the agent view"
' _ "$mode"
echo "PASS: $mode raised the session terminal"
