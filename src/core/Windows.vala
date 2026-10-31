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
        var root = parse (json);
        if (root != null && root.get_node_type () == Json.NodeType.ARRAY) {
            foreach (var node in root.get_array ().get_elements ()) {
                pids += (int) node.get_object ().get_int_member_with_default ("pid", 0);
            }
        }
        return pids;
    }

    // `niri msg --json windows`: a flat array of windows with an id and a pid. Returns -1 when none matches.
    public int64 niri_window (string json, int[] candidates) {
        var root = parse (json);
        if (root == null || root.get_node_type () != Json.NodeType.ARRAY) {
            return -1;
        }
        int[] pids = {};
        int64[] ids = {};
        foreach (var node in root.get_array ().get_elements ()) {
            var window = node.get_object ();
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

    // A KWin script that activates the window of the nearest candidate. Plasma 5 names windows "clients".
    public string kwin_script (int[] candidates) {
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
}
""".printf (list.str);
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
            if (!node.has_member (member)) {
                continue;
            }
            foreach (var child in node.get_array_member (member).get_elements ()) {
                foreach (var nested in collect_sway (child.get_object ())) {
                    pids += nested;
                }
            }
        }
        return pids;
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
