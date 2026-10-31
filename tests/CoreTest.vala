using ClaudeAgents;

class FakeDesktop : Object, Desktop {
    public int located = 0;

    public async void refresh_windows () {
    }

    public void locate (Session session) {
        located++;
    }

    public void activate (Session session, string claude_path) {
    }

    public void open_agent_view (string claude_path) {
    }

    public void set_dock_badge (int count) {
    }
}

const string FIRST = """[
    {"id": "a1", "sessionId": "s-1", "cwd": "/home/me/acme-api", "kind": "interactive", "status": "busy", "pid": 0},
    {"id": "b2", "kind": "background", "state": "waiting", "name": "nightly fix", "cwd": "/home/me/acme-web"}
]""";

const string SECOND = """[
    {"id": "a1", "sessionId": "s-1", "cwd": "/home/me/acme-api", "kind": "interactive", "status": "idle", "pid": 0}
]""";

void main (string[] args) {
    // Keep transcript lookups away from the real ~/.claude.
    string home;
    try {
        home = DirUtils.make_tmp ("core-test-XXXXXX");
    } catch (FileError e) {
        error (e.message);
    }
    DirUtils.create_with_parents (Path.build_filename (home, ".claude", "projects"), 0755);
    Environment.set_variable ("HOME", home, true);
    Test.init (ref args);

    Test.add_func ("/category/from_status", () => {
        assert (Category.from_status ("waiting") == Category.ATTENTION);
        assert (Category.from_status ("idle") == Category.READY);
        assert (Category.from_status ("busy") == Category.WORKING);
        assert (Category.from_status ("something-new") == Category.WORKING);
    });

    Test.add_func ("/session/environ", () => {
        var session = new Session ("s");
        assert (session.environ ("PATH") == null);
        // /proc/<pid>/environ holds the environment the process started with; PATH is never changed here.
        session.pid = (int) Posix.getpid ();
        assert (session.environ ("PATH") == Environment.get_variable ("PATH"));
        assert (session.environ ("NOT_SET_ANYWHERE") == null);
    });

    Test.add_func ("/terminal-focus/command", () => {
        var env = new HashTable<string, string> (str_hash, str_equal);
        assert (TerminalFocus.command ((name) => env.lookup (name)) == null);

        env.insert ("TMUX", "/tmp/tmux-1000/default,4242,0");
        env.insert ("TMUX_PANE", "%3");
        var tmux = string.joinv (" ", TerminalFocus.command ((name) => env.lookup (name)));
        assert (tmux == "tmux -S /tmp/tmux-1000/default select-window -t %3 ; select-pane -t %3 ; switch-client -t %3");

        env.remove_all ();
        env.insert ("KITTY_WINDOW_ID", "7");
        // kitty without remote control enabled exports no socket, so it cannot be driven.
        assert (TerminalFocus.command ((name) => env.lookup (name)) == null);
        env.insert ("KITTY_LISTEN_ON", "unix:/tmp/kitty");
        var kitty = string.joinv (" ", TerminalFocus.command ((name) => env.lookup (name)));
        assert (kitty == "kitty @ --to unix:/tmp/kitty focus-window --match id:7");

        env.remove_all ();
        env.insert ("WEZTERM_PANE", "12");
        var wezterm = string.joinv (" ", TerminalFocus.command ((name) => env.lookup (name)));
        assert (wezterm == "wezterm cli activate-pane --pane-id 12");

        env.remove_all ();
        env.insert ("GHOSTTY_SURFACE_ID", "0x00005555deadbeef");
        var ghostty = TerminalFocus.command ((name) => env.lookup (name));
        assert (ghostty[0] == "gdbus" && ghostty[9] == "present-surface" && ghostty[10] == "[<uint64 0x00005555deadbeef>]");

        env.remove_all ();
        env.insert ("KONSOLE_DBUS_SERVICE", ":1.42");
        env.insert ("KONSOLE_DBUS_WINDOW", "/Windows/1");
        env.insert ("KONSOLE_DBUS_SESSION", "/Sessions/3");
        var konsole = string.joinv (" ", TerminalFocus.command ((name) => env.lookup (name)));
        assert (konsole == "gdbus call --session --dest :1.42 --object-path /Windows/1 --method org.kde.konsole.Window.setCurrentSession 3");
    });

    Test.add_func ("/windows/ancestors", () => {
        var chain = Windows.ancestors ((int) Posix.getpid ());
        assert (chain.length >= 2);
        assert (chain[0] == (int) Posix.getpid ());
        assert (chain[1] == (int) Posix.getppid ());
        assert (Windows.ancestors (0).length == 0);
    });

    Test.add_func ("/windows/match", () => {
        assert (Windows.first_owner ({ 30, 20, 10 }, { 7, 10, 20 }) == 20);
        assert (Windows.first_owner ({ 30 }, { 7 }) == 0);

        var sway = """{"id": 1, "nodes": [{"id": 2, "nodes": [{"id": 3, "pid": 111, "nodes": []}],
                       "floating_nodes": [{"id": 4, "pid": 222}]}]}""";
        var sway_pids = Windows.sway_pids (sway);
        assert (sway_pids.length == 2 && sway_pids[0] == 111 && sway_pids[1] == 222);

        var hyprland_pids = Windows.hyprland_pids ("""[{"address": "0x1", "pid": 333}, {"address": "0x2", "pid": 444}]""");
        assert (hyprland_pids.length == 2 && hyprland_pids[1] == 444);

        var niri = """[{"id": 7, "pid": 555}, {"id": 9, "pid": 666}]""";
        assert (Windows.niri_window (niri, { 1, 666, 555 }) == 9);
        assert (Windows.niri_window (niri, { 1 }) == -1);
        assert (Windows.sway_pids ("not json").length == 0);

        var script = Windows.kwin_script ({ 12, 34 });
        assert ("const pids = [12,34];" in script);
        assert ("workspace.activeWindow = match;" in script);
    });

    Test.add_func ("/monitor/apply", () => {
        var desktop = new FakeDesktop ();
        var monitor = new SessionMonitor (desktop);
        var transitions = new GenericArray<string> ();
        var removed = new GenericArray<string> ();
        monitor.transitioned.connect ((session, previous, is_new) => transitions.add (session.key));
        monitor.removed.connect ((session) => removed.add (session.key));

        monitor.apply (FIRST);
        assert (monitor.sessions.length == 2);
        assert (monitor.count (Category.ATTENTION) == 1);
        assert (desktop.located == 2);
        // The first poll is the starting state, not a change.
        assert (transitions.length == 0);

        var background = monitor.lookup ("b2");
        assert (background != null && background.background);
        assert (background.title == "nightly fix");
        assert (monitor.lookup ("s-1").project == "acme-api");

        monitor.apply (SECOND);
        assert (monitor.sessions.length == 1);
        assert (monitor.lookup ("s-1").category == Category.READY);
        assert (transitions.length == 1 && transitions[0] == "s-1");
        assert (removed.length == 1 && removed[0] == "b2");
        assert (monitor.lookup ("b2") == null);
    });

    Test.run ();

    DirUtils.remove (Path.build_filename (home, ".claude", "projects"));
    DirUtils.remove (Path.build_filename (home, ".claude"));
    DirUtils.remove (home);
}
