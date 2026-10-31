// Finds the window that hosts a session by process id: the terminal is one of the claude process's ancestors.
namespace ClaudeAgents.Windows {
    public int[] ancestors (int pid) {
        int[] chain = {};
        for (var depth = 0; pid > 1 && depth < 64; depth++) {
            chain += pid;
            pid = parent_of (pid);
        }
        return chain;
    }

    // The first candidate, nearest ancestor first, that owns one of the windows.
    public int first_owner (int[] candidates, int[] window_pids) {
        foreach (var candidate in candidates) {
            foreach (var owner in window_pids) {
                if (candidate == owner) {
                    return candidate;
                }
            }
        }
        return 0;
    }

    // `swaymsg -t get_tree -r`: windows are nested containers with a pid.
    public int[] sway_pids (string json) {
        var root = parse (json);
        if (root == null || root.get_node_type () != Json.NodeType.OBJECT) {
            return {};
        }
        return collect_sway (root.get_object ());
    }

    // `hyprctl clients -j`: a flat array of windows with a pid.
    public int[] hyprland_pids (string json) {
        int[] pids = {};
        foreach (var window in objects (parse (json))) {
            pids += (int) window.get_int_member_with_default ("pid", 0);
        }
        return pids;
    }

    // `niri msg --json windows`: a flat array of windows with an id and a pid. Returns -1 when none matches.
    public int64 niri_window (string json, int[] candidates) {
        int[] pids = {};
        int64[] ids = {};
        foreach (var window in objects (parse (json))) {
            pids += (int) window.get_int_member_with_default ("pid", 0);
            ids += window.get_int_member_with_default ("id", -1);
        }
        var owner = first_owner (candidates, pids);
        for (var i = 0; owner != 0 && i < pids.length; i++) {
            if (pids[i] == owner) {
                return ids[i];
            }
        }
        return -1;
    }

    public const string KWIN_REPLY_PATH = "/io/github/rezk2ll/ClaudeAgents";
    public const string KWIN_REPLY_INTERFACE = "io.github.rezk2ll.ClaudeAgents.Raise";

    // A KWin script that activates the window of the nearest candidate. Plasma 5 names windows "clients". KWin
    // gives no result for a script, so when no window matches it calls Missed on reply_to over D-Bus, with the
    // click it was run for.
    public string kwin_script (int[] candidates, string reply_to, uint click) {
        var list = new StringBuilder ();
        foreach (var pid in candidates) {
            list.append ("%s%d".printf (list.len > 0 ? "," : "", pid));
        }
        return """const pids = [%s];
const windows = workspace.windowList ? workspace.windowList () : workspace.clientList ();
const match = pids.map (pid => windows.find (w => w.pid === pid)).find (w => w);
if (match) {
    match.minimized = false;
    if (workspace.windowList) {
        workspace.activeWindow = match;
    } else {
        workspace.activeClient = match;
    }
} else {
    callDBus ("%s", "%s", "%s", "Missed", "%u");
}
""".printf (list.str, reply_to, KWIN_REPLY_PATH, KWIN_REPLY_INTERFACE, click);
    }

    private int parent_of (int pid) {
        string stat;
        try {
            FileUtils.get_contents ("/proc/%d/stat".printf (pid), out stat);
        } catch (FileError e) {
            return 0;
        }
        // "pid (comm) state ppid ...", where comm may itself contain spaces and parentheses.
        var fields = stat.substring (stat.last_index_of_char (')') + 2).split (" ");
        return fields.length > 1 ? int.parse (fields[1]) : 0;
    }

    private int[] collect_sway (Json.Object node) {
        int[] pids = {};
        var pid = node.get_int_member_with_default ("pid", 0);
        if (pid > 0) {
            pids += (int) pid;
        }
        foreach (var member in new string[] { "nodes", "floating_nodes" }) {
            foreach (var child in objects (node.get_member (member))) {
                foreach (var nested in collect_sway (child)) {
                    pids += nested;
                }
            }
        }
        return pids;
    }

    // The object elements of a JSON array; anything else yields none.
    private Json.Object[] objects (Json.Node? node) {
        Json.Object[] result = {};
        if (node == null || node.get_node_type () != Json.NodeType.ARRAY) {
            return result;
        }
        foreach (var element in node.get_array ().get_elements ()) {
            if (element.get_node_type () == Json.NodeType.OBJECT) {
                result += element.get_object ();
            }
        }
        return result;
    }

    private Json.Node? parse (string json) {
        var parser = new Json.Parser ();
        try {
            parser.load_from_data (json);
        } catch (Error e) {
            return null;
        }
        return parser.get_root ();
    }
}
