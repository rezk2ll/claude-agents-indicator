namespace ClaudeAgents.TerminalFocus {
    public delegate string? Lookup (string name);

    public string[]? command (Lookup environ) {
        var tmux = environ ("TMUX");
        var pane = environ ("TMUX_PANE");
        if (tmux != null && pane != null) {
            // TMUX is "socket,server pid,session"; switch-client goes last because it fails when no client is attached.
            return {
                "tmux", "-S", tmux.split (",")[0],
                "select-window", "-t", pane, ";", "select-pane", "-t", pane, ";", "switch-client", "-t", pane,
            };
        }

        var kitty_window = environ ("KITTY_WINDOW_ID");
        var kitty_socket = environ ("KITTY_LISTEN_ON");
        if (kitty_window != null && kitty_socket != null) {
            return { "kitty", "@", "--to", kitty_socket, "focus-window", "--match", "id:" + kitty_window };
        }

        var wezterm_pane = environ ("WEZTERM_PANE");
        if (wezterm_pane != null) {
            return { "wezterm", "cli", "activate-pane", "--pane-id", wezterm_pane };
        }

        // Ghostty exports the surface id from 1.4 on; present-surface selects the tab and presents its window.
        var ghostty_surface = environ ("GHOSTTY_SURFACE_ID");
        if (ghostty_surface != null) {
            return {
                "gdbus", "call", "--session", "--dest", "com.mitchellh.ghostty", "--object-path", "/com/mitchellh/ghostty",
                "--method", "org.gtk.Actions.Activate", "present-surface", "[<uint64 %s>]".printf (ghostty_surface), "{}",
            };
        }

        // Konsole selects the tab but does not raise its window; the desktop raises the window on its own.
        var konsole_service = environ ("KONSOLE_DBUS_SERVICE");
        var konsole_window = environ ("KONSOLE_DBUS_WINDOW");
        var konsole_session = environ ("KONSOLE_DBUS_SESSION");
        if (konsole_service != null && konsole_window != null && konsole_session != null) {
            return {
                "gdbus", "call", "--session", "--dest", konsole_service, "--object-path", konsole_window,
                "--method", "org.kde.konsole.Window.setCurrentSession", Path.get_basename (konsole_session),
            };
        }
        return null;
    }
}
