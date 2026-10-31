public class ClaudeAgents.SessionMonitor : Object {
    private const uint POLL_SECONDS = 3;
    private const int64 TRANSCRIPT_TAIL_BYTES = 1024 * 1024;
    private const int64 TRANSCRIPT_SEARCH_INTERVAL = 30;

    public signal void changed ();
    public signal void transitioned (Session session, Category previous, bool is_new);
    public signal void removed (Session session);

    public Desktop desktop { get; construct; }
    public string claude_path { get; private set; }
    public string? error { get; private set; }
    public GenericArray<Session> sessions { get; private set; default = new GenericArray<Session> (); }
    public Usage usage { get; private set; default = new Usage (); }

    private HashTable<string, Session> by_key = new HashTable<string, Session> (str_hash, str_equal);
    private string projects_dir;
    private bool polling = false;
    private bool first_poll = true;

    public SessionMonitor (Desktop desktop) {
        Object (desktop: desktop);
    }

    construct {
        // wingpanel does not inherit the login shell PATH, so ~/.local/bin is often missing.
        claude_path = Environment.find_program_in_path ("claude")
            ?? Path.build_filename (Environment.get_home_dir (), ".local", "bin", "claude");
        projects_dir = Path.build_filename (Environment.get_home_dir (), ".claude", "projects");
    }

    public void start () {
        refresh.begin ();
        Timeout.add_seconds (POLL_SECONDS, () => {
            refresh.begin ();
            return Source.CONTINUE;
        });
    }

    public Session? lookup (string key) {
        return by_key.lookup (key);
    }

    public int count (Category category) {
        int n = 0;
        foreach (var session in sessions) {
            if (session.category == category) {
                n++;
            }
        }
        return n;
    }

    public async void refresh () {
        if (polling) {
            return;
        }
        polling = true;
        string? output = null;
        try {
            var proc = new Subprocess.newv (
                { claude_path, "agents", "--json" },
                SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_SILENCE
            );
            yield proc.communicate_utf8_async (null, null, out output, null);
            error = proc.get_successful () ? null : "claude agents exited with an error";
        } catch (Error e) {
            error = "Could not run claude: %s".printf (e.message);
        }

        if (error == null && output != null) {
            yield desktop.refresh_windows ();
            apply (output);
            usage.refresh (sessions);
        }
        polling = false;
        changed ();
    }

    // Public so tests can feed `claude agents --json` output without running claude.
    public void apply (string json) {
        var parser = new Json.Parser ();
        try {
            parser.load_from_data (json);
        } catch (Error e) {
            error = "Unreadable output from claude agents";
            return;
        }
        var root = parser.get_root ();
        if (root == null || root.get_node_type () != Json.NodeType.ARRAY) {
            return;
        }

        var current = new GenericArray<Session> ();
        foreach (unowned var node in root.get_array ().get_elements ()) {
            unowned var obj = node.get_object ();
            if (obj == null) {
                continue;
            }
            var id = obj.get_string_member_with_default ("id", "");
            var session_id = obj.get_string_member_with_default ("sessionId", "");
            var key = session_id != "" ? session_id : id;
            if (key == "") {
                continue;
            }

            var session = by_key.lookup (key);
            var is_new = session == null;
            if (is_new) {
                session = new Session (key);
                by_key.insert (key, session);
            }
            var previous = session.category;

            session.id = id;
            session.session_id = session_id;
            session.cwd = obj.get_string_member_with_default ("cwd", "");
            session.name = obj.get_string_member_with_default ("name", "");
            session.background = obj.get_string_member_with_default ("kind", "") == "background";
            // Background sessions report "state", interactive ones report "status".
            session.status = obj.get_string_member_with_default (session.background ? "state" : "status", "");
            session.category = Category.from_status (session.status);
            session.started_at = obj.get_int_member_with_default ("startedAt", 0) / 1000;

            var pid = (int) obj.get_int_member_with_default ("pid", 0);
            if (pid != session.pid) {
                session.pid = pid;
                session.terminal_id = null;
            }

            read_transcript (session);
            desktop.locate (session);

            if (!first_poll && (is_new || previous != session.category)) {
                transitioned (session, previous, is_new);
            }
            current.add (session);
        }

        var alive = new GenericSet<string> (str_hash, str_equal);
        foreach (var session in current) {
            alive.add (session.key);
        }
        foreach (var session in sessions) {
            if (!alive.contains (session.key)) {
                by_key.remove (session.key);
                removed (session);
            }
        }

        sessions = current;
        first_poll = false;
    }

    private void read_transcript (Session session) {
        session.last_activity = session.started_at;
        if (session.transcript_path == null) {
            session.transcript_path = find_transcript (session);
            if (session.transcript_path == null) {
                return;
            }
        }

        try {
            var file = File.new_for_path (session.transcript_path);
            var info = file.query_info (
                FileAttribute.TIME_MODIFIED + "," + FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE
            );
            var modified = info.get_modification_date_time ();
            var mtime = modified != null ? modified.to_unix () : session.started_at;
            session.last_activity = mtime;
            if (mtime == session.transcript_mtime) {
                return;
            }
            session.transcript_mtime = mtime;

            var stream = file.read ();
            stream.seek (int64.max (0, info.get_size () - TRANSCRIPT_TAIL_BYTES), SeekType.SET);
            var lines = new DataInputStream (stream);
            string? line;
            while ((line = lines.read_line ()) != null) {
                if (line.contains ("\"type\":\"ai-title\"")) {
                    session.ai_title = string_member (line, "aiTitle") ?? session.ai_title;
                } else if (line.contains ("\"type\":\"last-prompt\"")) {
                    var prompt = string_member (line, "lastPrompt");
                    if (prompt != null) {
                        session.last_prompt = prompt.replace ("\n", " ").strip ();
                    }
                }
            }
        } catch (Error e) {
            session.transcript_path = null;
        }
    }

    private string? find_transcript (Session session) {
        if (session.session_id == "") {
            return null;
        }
        var file_name = session.session_id + ".jsonl";
        var guess = Path.build_filename (projects_dir, project_dir_name (session.cwd), file_name);
        if (FileUtils.test (guess, FileTest.EXISTS)) {
            return guess;
        }

        // Worktree and renamed sessions live under other project folders; scanning them all is costly, so throttle it.
        var now = get_real_time () / 1000000;
        if (now - session.transcript_searched_at < TRANSCRIPT_SEARCH_INTERVAL) {
            return null;
        }
        session.transcript_searched_at = now;
        try {
            var dir = Dir.open (projects_dir);
            string? entry;
            while ((entry = dir.read_name ()) != null) {
                var path = Path.build_filename (projects_dir, entry, file_name);
                if (FileUtils.test (path, FileTest.EXISTS)) {
                    return path;
                }
            }
        } catch (FileError e) {
            warning ("Cannot scan %s: %s", projects_dir, e.message);
        }
        return null;
    }


    private static string project_dir_name (string cwd) {
        var result = new StringBuilder ();
        unichar c;
        for (int i = 0; cwd.get_next_char (ref i, out c);) {
            result.append_unichar (c.isalnum () && c < 128 ? c : '-');
        }
        return result.str;
    }

    private static string? string_member (string line, string member) {
        var parser = new Json.Parser ();
        try {
            parser.load_from_data (line);
        } catch (Error e) {
            return null;
        }
        var root = parser.get_root ();
        if (root == null || root.get_node_type () != Json.NodeType.OBJECT) {
            return null;
        }
        var value = root.get_object ().get_string_member_with_default (member, "");
        return value != "" ? value : null;
    }
}
