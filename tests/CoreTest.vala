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
