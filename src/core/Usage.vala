public class ClaudeAgents.Usage : Object {
    private const double HIGH = 80;

    // Raised when a window rises to HIGH, not while it stays there.
    public signal void high (string window, double used, int64 resets_at);

    public double five_hour { get; private set; }
    public int64 five_hour_resets_at { get; private set; }
    public double seven_day { get; private set; }
    public int64 seven_day_resets_at { get; private set; }

    private string status_dir;
    private string status_file;
    private string? source_path;
    private int64 source_mtime = -1;
    private bool five_hour_high = false;
    private bool seven_day_high = false;

    construct {
        // The JSON Claude Code hands to the status line carries rate_limits. cctop's status-line shim saves it per
        // session; without cctop, the status line command can tee it to one file.
        status_dir = Path.build_filename (Environment.get_home_dir (), ".cctop", "status");
        status_file = Path.build_filename (Environment.get_user_runtime_dir (), "claude-agents-status.json");
    }

    public bool available {
        get {
            return source_path != null;
        }
    }

    // Reads the freshest status, from the teed file or the live sessions; returns true when the numbers changed.
    public bool refresh (GenericArray<Session> sessions) {
        int64 newest_mtime = modified_time (status_file);
        string? newest = newest_mtime >= 0 ? status_file : null;
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
        var limits = member_object (root.get_object (), "rate_limits");
        if (limits == null) {
            return false;
        }

        source_path = newest;
        source_mtime = newest_mtime;
        five_hour = percentage (limits, "five_hour");
        five_hour_resets_at = resets_at (limits, "five_hour");
        seven_day = percentage (limits, "seven_day");
        seven_day_resets_at = resets_at (limits, "seven_day");
        report ("5-hour", five_hour, five_hour_resets_at, ref five_hour_high);
        report ("Weekly", seven_day, seven_day_resets_at, ref seven_day_high);
        return true;
    }

    private void report (string window, double used, int64 resets_at, ref bool was_high) {
        var is_high = current (used, resets_at) >= HIGH;
        if (is_high && !was_high) {
            high (window, used, resets_at);
        }
        was_high = is_high;
    }

    // A window that already reset has not been reported again yet, so its old percentage no longer applies.
    public static double current (double used, int64 resets_at) {
        return resets_at > 0 && resets_at <= get_real_time () / 1000000 ? 0 : used;
    }

    private static double percentage (Json.Object limits, string window) {
        var obj = member_object (limits, window);
        return obj != null ? obj.get_double_member_with_default ("used_percentage", 0) : 0;
    }

    private static int64 resets_at (Json.Object limits, string window) {
        var obj = member_object (limits, window);
        return obj != null ? obj.get_int_member_with_default ("resets_at", 0) : 0;
    }

    // Any window may be missing from the status, and get_object_member is critical on a missing member.
    private static Json.Object? member_object (Json.Object obj, string name) {
        var node = obj.get_member (name);
        return node != null && node.get_node_type () == Json.NodeType.OBJECT ? node.get_object () : null;
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
