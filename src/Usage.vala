public class ClaudeAgents.Usage : Object {
    public double five_hour { get; private set; }
    public int64 five_hour_resets_at { get; private set; }
    public double seven_day { get; private set; }
    public int64 seven_day_resets_at { get; private set; }

    private string status_dir;
    private string? source_path;
    private int64 source_mtime = -1;

    construct {
        // cctop's status-line shim saves the JSON Claude Code hands to the status line, rate_limits included.
        status_dir = Path.build_filename (Environment.get_home_dir (), ".cctop", "status");
    }

    public bool available {
        get {
            return source_path != null;
        }
    }

    // Reads the freshest status among the live sessions; returns true when the numbers changed.
    public bool refresh (GenericArray<Session> sessions) {
        string? newest = null;
        int64 newest_mtime = -1;
        foreach (var session in sessions) {
            if (session.session_id == "") {
                continue;
            }
            var path = Path.build_filename (status_dir, session.session_id + ".json");
            var mtime = modified_time (path);
            if (mtime > newest_mtime) {
                newest = path;
                newest_mtime = mtime;
            }
        }
        if (newest == null) {
            return false;
        }
        if (newest == source_path && newest_mtime == source_mtime) {
            return false;
        }

        var parser = new Json.Parser ();
        try {
            parser.load_from_file (newest);
        } catch (Error e) {
            return false;
        }
        var root = parser.get_root ();
        if (root == null || root.get_node_type () != Json.NodeType.OBJECT) {
            return false;
        }
        var limits = root.get_object ().get_object_member ("rate_limits");
        if (limits == null) {
            return false;
        }

        source_path = newest;
        source_mtime = newest_mtime;
        five_hour = percentage (limits, "five_hour");
        five_hour_resets_at = resets_at (limits, "five_hour");
        seven_day = percentage (limits, "seven_day");
        seven_day_resets_at = resets_at (limits, "seven_day");
        return true;
    }

    // A window that already reset has not been reported again yet, so its old percentage no longer applies.
    public static double current (double used, int64 resets_at) {
        return resets_at > 0 && resets_at <= get_real_time () / 1000000 ? 0 : used;
    }

    private static double percentage (Json.Object limits, string window) {
        var obj = limits.get_object_member (window);
        return obj != null ? obj.get_double_member_with_default ("used_percentage", 0) : 0;
    }

    private static int64 resets_at (Json.Object limits, string window) {
        var obj = limits.get_object_member (window);
        return obj != null ? obj.get_int_member_with_default ("resets_at", 0) : 0;
    }

    private static int64 modified_time (string path) {
        try {
            var info = File.new_for_path (path).query_info (FileAttribute.TIME_MODIFIED, FileQueryInfoFlags.NONE);
            var modified = info.get_modification_date_time ();
            return modified != null ? modified.to_unix () : -1;
        } catch (Error e) {
            return -1;
        }
    }
}
