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
        return null;
    }
}
