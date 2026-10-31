// Works on any desktop: tabs are selected through the terminal's own remote control, and the terminal's window
// is raised through the compositor (Sway, Hyprland, niri, KWin) or, on X11, through xdotool.
public class ClaudeAgents.GenericDesktop : Object, Desktop {
    private const string KWIN_PLUGIN = "claude-agents-raise";

    private enum Compositor {
        NONE,
        SWAY,
        HYPRLAND,
        NIRI,
        KWIN,
        X11,
    }

    private Compositor compositor;

    construct {
        compositor = detect_compositor ();
    }

    public async void refresh_windows () {
    }

    public void locate (Session session) {
        var focus = TerminalFocus.command ((name) => session.environ (name));
        // Autostart may run with a shorter PATH than the user's shell, so check the tool is there.
        if (focus != null && Environment.find_program_in_path (focus[0]) != null) {
            session.terminal_id = focus[0];
        } else {
            session.terminal_id = compositor != Compositor.NONE && session.pid > 0 ? "window" : null;
        }
    }

    public void activate (Session session, string claude_path) {
        var focus = TerminalFocus.command ((name) => session.environ (name));
        var selected = focus != null && spawn (null, focus);
        // A background session's parent may still be the terminal that dispatched it, which is not where it runs.
        var raised = !session.background && session.pid > 0 && compositor != Compositor.NONE
                     && raise_window (candidates (session));
        if (selected || raised) {
            return;
        }
        if (session.background) {
            open_terminal (session.cwd, { claude_path, "attach", session.id });
        } else {
            open_agent_view (claude_path);
        }
    }

    public void open_agent_view (string claude_path) {
        open_terminal (null, { claude_path, "agents" });
    }

    public void set_dock_badge (int count) {
    }

    // The processes that may own the session's window, nearest first. Inside tmux the claude process descends
    // from the tmux server, so the windows are those of the clients instead. switch-client moves the most recently
    // active client, and may not have run yet, so the clients are listed by activity rather than by session.
    private static int[] candidates (Session session) {
        var tmux = session.environ ("TMUX");
        if (tmux == null || session.environ ("TMUX_PANE") == null) {
            return Windows.ancestors (session.pid);
        }
        var output = run ({ "tmux", "-S", tmux.split (",")[0], "list-clients", "-F", "#{client_activity} #{client_pid}" });
        var clients = new GenericArray<string> ();
        foreach (var line in (output ?? "").split ("\n")) {
            if (" " in line) {
                clients.add (line);
            }
        }
        // Activity is a Unix time, so the latest sorts last as text.
        clients.sort ((a, b) => strcmp (b, a));
        int[] result = {};
        foreach (var line in clients.data) {
            foreach (var pid in Windows.ancestors (int.parse (line.split (" ")[1]))) {
                result += pid;
            }
        }
        return result;
    }

    private bool raise_window (int[] candidates) {
        if (candidates.length == 0) {
            return false;
        }
        switch (compositor) {
            case Compositor.SWAY:
                var owner = Windows.first_owner (candidates, Windows.sway_pids (run ({ "swaymsg", "-t", "get_tree", "-r" }) ?? ""));
                return owner != 0 && run ({ "swaymsg", "[pid=%d] focus".printf (owner) }) != null;
            case Compositor.HYPRLAND:
                var owner = Windows.first_owner (candidates, Windows.hyprland_pids (run ({ "hyprctl", "clients", "-j" }) ?? ""));
                if (owner == 0) {
                    return false;
                }
                // Hyprland 0.57 replaced the dispatcher syntax with Lua; hyprctl answers "ok" to the one it knows.
                if ((run ({ "hyprctl", "dispatch", "focuswindow", "pid:%d".printf (owner) }) ?? "").strip () == "ok") {
                    return true;
                }
                return (run ({ "hyprctl", "dispatch", "hl.dsp.focus({ window = \"pid:%d\" })".printf (owner) }) ?? "").strip () == "ok";
            case Compositor.NIRI:
                var id = Windows.niri_window (run ({ "niri", "msg", "--json", "windows" }) ?? "", candidates);
                return id >= 0 && run ({ "niri", "msg", "action", "focus-window", "--id", id.to_string () }) != null;
            case Compositor.KWIN:
                return raise_with_kwin (candidates);
            case Compositor.X11:
                foreach (var pid in candidates) {
                    var windows = run ({ "xdotool", "search", "--onlyvisible", "--pid", pid.to_string () });
                    if (windows != null && windows.strip () != "") {
                        return run ({ "xdotool", "windowactivate", windows.strip ().split ("\n")[0] }) != null;
                    }
                }
                return false;
            default:
                return false;
        }
    }

    // KWin runs scripts from files, so the script is written to the runtime directory, loaded and run. KWin reads it
    // after run returns, so the previous one is unloaded on the next click instead of right away.
    private static bool raise_with_kwin (int[] candidates) {
        var path = Path.build_filename (Environment.get_user_runtime_dir (), KWIN_PLUGIN + ".js");
        try {
            FileUtils.set_contents (path, Windows.kwin_script (candidates));
            var bus = Bus.get_sync (BusType.SESSION);
            kwin_call (bus, "/Scripting", "org.kde.kwin.Scripting", "unloadScript", new Variant ("(s)", KWIN_PLUGIN));
            var reply = kwin_call (bus, "/Scripting", "org.kde.kwin.Scripting", "loadScript", new Variant ("(ss)", path, KWIN_PLUGIN));
            int id;
            reply.get ("(i)", out id);
            // Plasma 6 puts loaded scripts under /Scripting, Plasma 5 at the root.
            try {
                kwin_call (bus, "/Scripting/Script%d".printf (id), "org.kde.kwin.Script", "run", null);
            } catch (Error e) {
                kwin_call (bus, "/%d".printf (id), "org.kde.kwin.Script", "run", null);
            }
            return true;
        } catch (Error e) {
            warning ("Cannot raise the window through KWin: %s", e.message);
            return false;
        }
    }

    private static Variant kwin_call (DBusConnection bus, string path, string iface, string method, Variant? args) throws Error {
        return bus.call_sync ("org.kde.KWin", path, iface, method, args, null, DBusCallFlags.NONE, 2000);
    }

    // Autostart may run with a shorter PATH than the user's shell, so each compositor counts only if its tool is there.
    private static Compositor detect_compositor () {
        if (Environment.get_variable ("SWAYSOCK") != null) {
            return has ("swaymsg") ? Compositor.SWAY : Compositor.NONE;
        } else if (Environment.get_variable ("HYPRLAND_INSTANCE_SIGNATURE") != null) {
            return has ("hyprctl") ? Compositor.HYPRLAND : Compositor.NONE;
        } else if (Environment.get_variable ("NIRI_SOCKET") != null) {
            return has ("niri") ? Compositor.NIRI : Compositor.NONE;
        } else if ((Environment.get_variable ("XDG_CURRENT_DESKTOP") ?? "").contains ("KDE")) {
            return Compositor.KWIN;
        } else if (Environment.get_variable ("XDG_SESSION_TYPE") != "wayland" && Environment.get_variable ("DISPLAY") != null) {
            return has ("xdotool") ? Compositor.X11 : Compositor.NONE;
        }
        // GNOME on Wayland lets no other program raise a window.
        return Compositor.NONE;
    }

    private static bool has (string program) {
        return Environment.find_program_in_path (program) != null;
    }

    // xdg-terminal-exec is the cross-desktop default terminal; Debian and Ubuntu also ship x-terminal-emulator.
    private void open_terminal (string? cwd, string[] command) {
        string[] argv;
        if (Environment.find_program_in_path ("xdg-terminal-exec") != null) {
            argv = { "xdg-terminal-exec" };
        } else if (Environment.find_program_in_path ("x-terminal-emulator") != null) {
            argv = { "x-terminal-emulator", "-e" };
        } else {
            warning ("No terminal found: install xdg-terminal-exec");
            return;
        }
        foreach (var arg in command) {
            argv += arg;
        }
        // The session's directory may be a worktree that has since been deleted.
        spawn (cwd != null && FileUtils.test (cwd, FileTest.IS_DIR) ? cwd : null, argv);
    }

    private static string? run (string[] argv) {
        try {
            string output;
            int status;
            Process.spawn_sync (null, argv, null, SpawnFlags.SEARCH_PATH | SpawnFlags.STDERR_TO_DEV_NULL, null, out output, null, out status);
            return Process.check_wait_status (status) ? output : null;
        } catch (Error e) {
            return null;
        }
    }

    private static bool spawn (string? cwd, string[] argv) {
        try {
            return Process.spawn_async (cwd, argv, null, SpawnFlags.SEARCH_PATH, null, null);
        } catch (SpawnError e) {
            warning ("Cannot run %s: %s", argv[0], e.message);
            return false;
        }
    }
}
