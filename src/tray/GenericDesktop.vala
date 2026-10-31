// Works on any desktop: it raises tabs through the terminal's own remote control and has no window list or dock.
public class ClaudeAgents.GenericDesktop : Object, Desktop {
    public async void refresh_windows () {
    }

    public void locate (Session session) {
        var focus = TerminalFocus.command ((name) => session.environ (name));
        // Autostart may run with a shorter PATH than the user's shell, so check the tool is there.
        var usable = focus != null && Environment.find_program_in_path (focus[0]) != null;
        session.terminal_id = usable ? focus[0] : null;
    }

    public void activate (Session session, string claude_path) {
        var focus = TerminalFocus.command ((name) => session.environ (name));
        if (focus != null && spawn (null, focus)) {
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

    private static bool spawn (string? cwd, string[] argv) {
        try {
            return Process.spawn_async (cwd, argv, null, SpawnFlags.SEARCH_PATH, null, null);
        } catch (SpawnError e) {
            warning ("Cannot run %s: %s", argv[0], e.message);
            return false;
        }
    }
}
