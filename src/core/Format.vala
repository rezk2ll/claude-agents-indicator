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
}
