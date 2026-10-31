// One-shot views of the sessions for status bars: a line of text, or the JSON a waybar custom module reads.
namespace ClaudeAgents.Summary {
    public string text (GenericArray<Session> sessions, string? error) {
        if (error != null) {
            return error;
        }
        string[] parts = {};
        foreach (var category in new Category[] { Category.ATTENTION, Category.READY, Category.WORKING }) {
            var n = count (sessions, category);
            if (n > 0) {
                parts += "%d %s".printf (n, category == Category.ATTENTION ? "need you" : category == Category.READY ? "your turn" : "working");
            }
        }
        return parts.length > 0 ? string.joinv (" · ", parts) : "no sessions";
    }

    // The fields of https://github.com/Alexays/Waybar/wiki/Module:-Custom with "return-type": "json".
    public string waybar (GenericArray<Session> sessions, string? error, Usage? usage) {
        var waiting = count (sessions, Category.ATTENTION);
        string[] lines = {};
        foreach (var category in new Category[] { Category.ATTENTION, Category.READY, Category.WORKING }) {
            foreach (var session in sessions) {
                if (session.category == category) {
                    lines += "%s: %s".printf (category.to_title (), Format.session (session));
                }
            }
        }
        if (usage != null && usage.available) {
            lines += Format.usage ("5-hour", usage.five_hour, usage.five_hour_resets_at);
            lines += Format.usage ("Weekly", usage.seven_day, usage.seven_day_resets_at);
        }

        string state;
        if (error != null) {
            state = "error";
        } else if (waiting > 0) {
            state = "attention";
        } else if (count (sessions, Category.READY) > 0) {
            state = "ready";
        } else {
            state = sessions.length > 0 ? "working" : "idle";
        }

        // Plain ifs: valac 0.56 frees the string of a parenthesized nested `?:` that mixes literals and allocated
        // strings before the call reads it.
        string text = (waiting > 0 ? waiting : sessions.length).to_string ();
        string tooltip = "No Claude Code sessions";
        if (error != null) {
            text = "!";
            tooltip = error;
        } else if (lines.length > 0) {
            tooltip = string.joinv ("\n", lines);
        }
        // Waybar reads both as Pango markup, and titles are free text.
        tooltip = Markup.escape_text (tooltip);
        var output = new Json.Object ();
        output.set_string_member ("text", text);
        output.set_string_member ("tooltip", tooltip);
        output.set_string_member ("class", state);
        output.set_string_member ("alt", state);
        if (usage != null && usage.available) {
            var used = double.max (Usage.current (usage.five_hour, usage.five_hour_resets_at),
                                   Usage.current (usage.seven_day, usage.seven_day_resets_at));
            output.set_int_member ("percentage", (int64) (used + 0.5));
        }
        var root = new Json.Node (Json.NodeType.OBJECT);
        root.set_object (output);
        var generator = new Json.Generator ();
        generator.root = root;
        return generator.to_data (null);
    }

    private int count (GenericArray<Session> sessions, Category category) {
        int n = 0;
        foreach (var session in sessions) {
            if (session.category == category) {
                n++;
            }
        }
        return n;
    }
}
