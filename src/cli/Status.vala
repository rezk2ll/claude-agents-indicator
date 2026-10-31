// Prints the sessions once and exits, for status bars that poll a command.
private class ClaudeAgents.NoDesktop : Object, Desktop {
    public async void refresh_windows () {
    }

    public void locate (Session session) {
    }

    public void activate (Session session, string claude_path) {
    }

    public void open_agent_view (string claude_path) {
    }

    public void set_dock_badge (int count) {
    }
}

int main (string[] args) {
    var waybar = false;
    foreach (var arg in args[1:args.length]) {
        if (arg == "--waybar") {
            waybar = true;
        } else {
            stderr.printf ("Usage: %s [--waybar]\n", Path.get_basename (args[0]));
            return arg == "--help" || arg == "-h" ? 0 : 2;
        }
    }

    var monitor = new ClaudeAgents.SessionMonitor (new ClaudeAgents.NoDesktop ());
    var loop = new MainLoop ();
    monitor.refresh.begin ((obj, res) => {
        monitor.refresh.end (res);
        loop.quit ();
    });
    loop.run ();

    // Not print (): it converts to the locale's charset, and status bars may run with the C locale.
    if (waybar) {
        // The error is in the JSON's class, so the bar keeps showing the module.
        stdout.printf ("%s\n", ClaudeAgents.Summary.waybar (monitor.sessions, monitor.error, monitor.usage));
        return 0;
    }
    stdout.printf ("%s\n", ClaudeAgents.Summary.text (monitor.sessions, monitor.error));
    return monitor.error != null ? 1 : 0;
}
