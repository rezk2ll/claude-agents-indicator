[DBus (name = "org.pantheon.gala.DesktopIntegration")]
public interface ClaudeAgents.GalaDesktop : Object {
    public struct Window {
        uint64 uid;
        HashTable<string, Variant> properties;
    }

    public abstract async Window[] get_windows () throws GLib.DBusError, GLib.IOError;
    public abstract async void focus_window (uint64 uid) throws GLib.DBusError, GLib.IOError;
}

public class ClaudeAgents.Desktop : Object {
    private const string AGENT_VIEW_TITLE = "claude agents";
    private const string TERMINAL_APP_ID = "io.elementary.terminal.desktop";
    private const string LAUNCHER_ENTRY_PATH = "/io/github/claude_agents_indicator";

    private GalaDesktop? gala = null;
    private DBusConnection? bus = null;
    private HashTable<uint64?, string> titles = new HashTable<uint64?, string> (int64_hash, int64_equal);
    private uint64 terminal_window = 0;
    private int dock_badge = -1;

    construct {
        connect_gala.begin ();
        try {
            bus = Bus.get_sync (BusType.SESSION);
        } catch (Error e) {
            warning ("Session bus unavailable: %s", e.message);
        }
    }

    // Terminal's own "process finished" notifications use this action to raise the window and select the tab.
    public void focus_terminal_tab (string terminal_id) {
        if (bus == null) {
            return;
        }
        var parameters = new Variant.tuple ({
            new Variant.string ("process-finished"),
            new Variant.array (VariantType.VARIANT, { new Variant.variant (new Variant.string (terminal_id)) }),
            new Variant.array (new VariantType ("{sv}"), {}),
        });
        bus.call.begin (
            "io.elementary.terminal", "/io/elementary/terminal", "org.gtk.Actions", "Activate",
            parameters, null, DBusCallFlags.NONE, -1, null, (obj, res) => {
                try {
                    bus.call.end (res);
                } catch (Error e) {
                    warning ("Cannot focus terminal tab: %s", e.message);
                }
            }
        );
    }

    // The dock shows Unity launcher counts as a badge on the app icon.
    public void set_dock_badge (int count) {
        if (bus == null || count == dock_badge) {
            return;
        }
        dock_badge = count;
        var properties = new VariantBuilder (new VariantType ("a{sv}"));
        properties.add ("{sv}", "count", new Variant.int64 (count));
        properties.add ("{sv}", "count-visible", new Variant.boolean (count > 0));
        try {
            bus.emit_signal (
                null, LAUNCHER_ENTRY_PATH, "com.canonical.Unity.LauncherEntry", "Update",
                new Variant.tuple ({ new Variant.string ("application://" + TERMINAL_APP_ID), properties.end () })
            );
        } catch (Error e) {
            warning ("Cannot update dock badge: %s", e.message);
        }
    }

    private async void connect_gala () {
        try {
            gala = yield Bus.get_proxy<GalaDesktop> (
                BusType.SESSION, "org.pantheon.gala", "/org/pantheon/gala/DesktopInterface"
            );
        } catch (Error e) {
            warning ("Gala desktop integration unavailable: %s", e.message);
        }
    }

    public async void refresh_windows () {
        if (gala == null) {
            return;
        }
        try {
            var windows = yield gala.get_windows ();
            titles.remove_all ();
            terminal_window = 0;
            foreach (var window in windows) {
                var title = window.properties.lookup ("title");
                if (title == null || !title.is_of_type (VariantType.STRING)) {
                    continue;
                }
                titles.insert (window.uid, title.get_string ());

                var app_id = window.properties.lookup ("app-id");
                if (terminal_window == 0 && app_id != null && app_id.is_of_type (VariantType.STRING)
                    && app_id.get_string () == TERMINAL_APP_ID && !title.get_string ().contains (AGENT_VIEW_TITLE)) {
                    terminal_window = window.uid;
                }
            }
        } catch (Error e) {
            warning ("Cannot list windows: %s", e.message);
        }
    }

    // Claude names its terminal tab after the conversation, but a window title only shows the tab in front.
    // Terminal exposes no way to switch tabs, so a hidden tab falls back to a terminal window.
    public uint64 find_session_window (string? title) {
        var uid = find_window (title);
        return uid != 0 ? uid : terminal_window;
    }

    public uint64 find_window (string? title) {
        if (title == null || title == "") {
            return 0;
        }
        uint64 found = 0;
        titles.foreach ((uid, window_title) => {
            if (window_title.has_suffix (title)) {
                found = uid;
            }
        });
        return found;
    }

    public void focus (uint64 uid) {
        if (gala == null) {
            return;
        }
        gala.focus_window.begin (uid, (obj, res) => {
            try {
                gala.focus_window.end (res);
            } catch (Error e) {
                warning ("Cannot focus window: %s", e.message);
            }
        });
    }

    public void open_agent_view (string claude_path) {
        var uid = find_window (AGENT_VIEW_TITLE);
        if (uid != 0) {
            focus (uid);
        } else {
            open_terminal (null, { claude_path, "agents" });
        }
    }

    public void open_terminal (string? cwd, string[] command) {
        string[] argv = { "io.elementary.terminal", "--new-window" };
        if (cwd != null && cwd != "") {
            argv += "--working-directory=" + cwd;
        }
        argv += "-x";
        foreach (var arg in command) {
            argv += arg;
        }
        try {
            Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
        } catch (SpawnError e) {
            warning ("Cannot open terminal: %s", e.message);
        }
    }
}
