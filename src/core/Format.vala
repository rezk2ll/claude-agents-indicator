namespace ClaudeAgents.Format {
    public string age (int64 unix_seconds) {
        if (unix_seconds <= 0) {
            return "";
        }
        var seconds = get_real_time () / 1000000 - unix_seconds;
        if (seconds < 60) {
            return "now";
        } else if (seconds < 3600) {
            return "%lldm".printf (seconds / 60);
        } else if (seconds < 86400) {
            return "%lldh".printf (seconds / 3600);
        }
        return "%lldd".printf (seconds / 86400);
    }

    public string? until (int64 resets_at) {
        var seconds = resets_at - get_real_time () / 1000000;
        if (resets_at <= 0 || seconds <= 0) {
            return null;
        }
        var days = seconds / 86400;
        var hours = (seconds % 86400) / 3600;
        var minutes = (seconds % 3600) / 60;
        if (days > 0) {
            return "%lldd %lldh".printf (days, hours);
        } else if (hours > 0) {
            return "%lldh %lldm".printf (hours, minutes);
        }
        return "%lldm".printf (minutes);
    }

    public string session (Session session) {
        // A session with no conversation title yet is titled after its project; say it once.
        var text = session.title == session.project ? session.title : "%s · %s".printf (session.title, session.project);
        if (session.waiting_for != null) {
            text = "%s · %s".printf (text, session.waiting_for);
        }
        var ago = age (session.last_activity);
        return ago != "" ? "%s · %s".printf (text, ago) : text;
    }

    public string usage (string name, double used, int64 resets_at) {
        var line = "%s %.0f%%".printf (name, Usage.current (used, resets_at));
        var remaining = until (resets_at);
        return remaining != null ? "%s · resets in %s".printf (line, remaining) : line;
    }
}
