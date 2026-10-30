public class ClaudeAgents.SessionRow : Gtk.ListBoxRow {
    private const string[] AVATAR_COLORS = {
        "strawberry", "orange", "lime", "mint", "blueberry", "grape", "bubblegum", "cocoa", "slate"
    };

    public Session session { get; construct; }

    private Gtk.Box dot;
    private Gtk.Label title_label;
    private Gtk.Label meta_label;
    private Gtk.Label time_label;
    private Gtk.Spinner spinner;
    private Gtk.Stack trailing;
    private string? dot_class = null;

    public SessionRow (Session session) {
        Object (session: session);
    }

    construct {
        var avatar = new Gtk.Label (initials (session.project)) {
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER,
            // Leaves room for the status dot to sit on the avatar's corner.
            margin_end = 3,
            margin_bottom = 3,
        };
        avatar.get_style_context ().add_class ("claude-avatar");
        avatar.get_style_context ().add_class (AVATAR_COLORS[session.cwd.hash () % AVATAR_COLORS.length]);

        dot = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
            halign = Gtk.Align.END,
            valign = Gtk.Align.END,
        };
        dot.get_style_context ().add_class ("claude-dot");

        var avatar_overlay = new Gtk.Overlay () {
            valign = Gtk.Align.CENTER,
        };
        avatar_overlay.add (avatar);
        avatar_overlay.add_overlay (dot);

        // max_width_chars = 1 stops long titles from widening the popover; the grid width decides instead.
        title_label = new Gtk.Label (null) {
            ellipsize = Pango.EllipsizeMode.END,
            hexpand = true,
            max_width_chars = 1,
            xalign = 0,
        };

        meta_label = new Gtk.Label (null) {
            ellipsize = Pango.EllipsizeMode.END,
            max_width_chars = 1,
            xalign = 0,
        };
        meta_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        meta_label.get_style_context ().add_class ("small-label");

        time_label = new Gtk.Label (null);
        time_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        time_label.get_style_context ().add_class ("claude-time");

        spinner = new Gtk.Spinner ();

        trailing = new Gtk.Stack () {
            halign = Gtk.Align.END,
            valign = Gtk.Align.CENTER,
            homogeneous = false,
        };
        trailing.add_named (time_label, "time");
        trailing.add_named (spinner, "spinner");

        var grid = new Gtk.Grid () {
            column_spacing = 9,
            margin_start = 9,
            margin_end = 12,
            margin_top = 4,
            margin_bottom = 4,
        };
        grid.attach (avatar_overlay, 0, 0, 1, 2);
        grid.attach (title_label, 1, 0);
        grid.attach (meta_label, 1, 1);
        grid.attach (trailing, 2, 0, 1, 2);

        add (grid);
        show_all ();
        update ();
    }

    public void update () {
        var category = session.category;

        title_label.label = session.title;
        meta_label.label = "%s · %s".printf (session.project, session.background ? "background" : session.describe_status ());

        if (dot_class != null) {
            dot.get_style_context ().remove_class (dot_class);
        }
        dot_class = category.to_style_class ();
        dot.get_style_context ().add_class (dot_class);

        if (category == Category.WORKING) {
            trailing.visible_child = spinner;
            spinner.active = true;
        } else {
            spinner.active = false;
            trailing.visible_child = time_label;
            time_label.label = format_age (session.last_activity);
        }
        if (category == Category.ATTENTION) {
            time_label.get_style_context ().add_class ("attention");
        } else {
            time_label.get_style_context ().remove_class ("attention");
        }

        tooltip_text = session.last_prompt != null ? "You: %s".printf (session.last_prompt) : null;
    }

    // Two letters, because many projects share a first word ("acme-api", "acme-web").
    private static string initials (string project) {
        var result = new StringBuilder ();
        var at_word_start = true;
        unichar c;
        for (int i = 0; project.get_next_char (ref i, out c);) {
            if (result.len >= 2) {
                break;
            } else if (!c.isalnum ()) {
                at_word_start = true;
            } else if (at_word_start) {
                result.append_unichar (c.toupper ());
                at_word_start = false;
            }
        }
        return result.len > 0 ? result.str : "?";
    }

    private static string format_age (int64 unix_seconds) {
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
}
