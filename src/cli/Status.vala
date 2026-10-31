// Prints the sessions for status bars: once, or a line per change with --follow.
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
    var follow = false;
    foreach (var arg in args[1:args.length]) {
        if (arg == "--waybar") {
            waybar = true;
        } else if (arg == "--follow") {
            follow = true;
        } else {
            stderr.printf ("Usage: %s [--waybar] [--follow]\n", Path.get_basename (args[0]));
            return arg == "--help" || arg == "-h" ? 0 : 2;
        }
    }

    var monitor = new ClaudeAgents.SessionMonitor (new ClaudeAgents.NoDesktop ());
    var loop = new MainLoop ();
    string? last = null;
    monitor.changed.connect (() => {
        string line;
        if (waybar) {
            line = ClaudeAgents.Summary.waybar (monitor.sessions, monitor.error, monitor.usage);
        } else {
            line = ClaudeAgents.Summary.text (monitor.sessions, monitor.error);
        }
        // Not print (): it converts to the locale's charset, and status bars may run with the C locale.
        if (line != last) {
            stdout.printf ("%s\n", line);
            stdout.flush ();
            last = line;
        }
        if (!follow) {
            loop.quit ();
        }
    });
    if (follow) {
        monitor.start ();
    } else {
        monitor.refresh.begin ();
        // Bars run this on an interval, so a claude that hangs must not pile up processes.
        Timeout.add_seconds (10, () => {
            var error = "claude agents did not answer";
            if (waybar) {
                stdout.printf ("%s\n", ClaudeAgents.Summary.waybar (monitor.sessions, error, null));
                Process.exit (0);
            }
            stdout.printf ("%s\n", error);
            Process.exit (1);
        });
    }
    loop.run ();
    // With --waybar the error is in the JSON's class, so the bar keeps showing the module.
    return monitor.error != null && !waybar ? 1 : 0;
}
