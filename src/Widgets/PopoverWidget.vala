public class ClaudeAgents.PopoverWidget : Gtk.Box {
    public signal void session_activated (Session session);
    public signal void agent_view_requested ();

    public SessionMonitor monitor { get; construct; }
    public Preferences preferences { get; construct; }

    private Gtk.ListBox list;
    private Gtk.Label placeholder_label;
    private UsageWidget usage_widget;
    private Gtk.Separator usage_separator;
    private HashTable<string, SessionRow> rows = new HashTable<string, SessionRow> (str_hash, str_equal);

    public PopoverWidget (SessionMonitor monitor, Preferences preferences) {
        Object (monitor: monitor, preferences: preferences, orientation: Gtk.Orientation.VERTICAL);
    }

    construct {
        width_request = 340;

        var placeholder_icon = new Gtk.Image.from_icon_name ("claude-agents-symbolic", Gtk.IconSize.DIALOG) {
            pixel_size = 48,
        };
        placeholder_icon.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        placeholder_label = new Gtk.Label ("No Claude sessions running") {
            max_width_chars = 30,
            wrap = true,
            justify = Gtk.Justification.CENTER,
        };
        placeholder_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        var placeholder = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
            margin = 24,
        };
        placeholder.add (placeholder_icon);
        placeholder.add (placeholder_label);
        placeholder.show_all ();

        list = new Gtk.ListBox () {
            selection_mode = Gtk.SelectionMode.NONE,
            activate_on_single_click = true,
        };
        list.get_style_context ().add_class ("claude-list");
        list.set_placeholder (placeholder);
        list.set_sort_func (sort_rows);
        list.set_header_func (update_header);
        list.row_activated.connect ((row) => {
            session_activated (((SessionRow) row).session);
        });

        var scrolled = new Gtk.ScrolledWindow (null, null) {
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            max_content_height = 560,
            propagate_natural_height = true,
        };
        scrolled.add (list);

        var notifications_switch = new SwitchModelButton ("Notifications");
        preferences.bind_property (
            "notifications", notifications_switch, "active", BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL
        );

        var agent_view_button = new Gtk.ModelButton () {
            text = "Agent View…",
        };
        agent_view_button.clicked.connect (() => agent_view_requested ());

        usage_widget = new UsageWidget (monitor.usage);
        usage_separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);

        add (usage_widget);
        add (usage_separator);
        add (scrolled);
        add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL) { margin_top = 3, margin_bottom = 3 });
        add (notifications_switch);
        add (agent_view_button);
        show_all ();
        usage_widget.visible = false;
        usage_separator.visible = false;

        monitor.changed.connect (sync);
    }

    public static string describe_counts (int attention, int ready, int working) {
        string[] parts = {};
        if (attention > 0) {
            parts += "%d need%s you".printf (attention, attention == 1 ? "s" : "");
        }
        if (ready > 0) {
            parts += "%d your turn".printf (ready);
        }
        if (working > 0) {
            parts += "%d working".printf (working);
        }
        return parts.length > 0 ? string.joinv (" · ", parts) : "No sessions";
    }

    private void sync () {
        placeholder_label.label = monitor.error ?? "No Claude sessions running";

        var show_usage = monitor.usage.available;
        if (show_usage) {
            usage_widget.update ();
        }
        usage_widget.visible = show_usage;
        usage_separator.visible = show_usage;

        var alive = new GenericSet<string> (str_hash, str_equal);
        foreach (var session in monitor.sessions) {
            alive.add (session.key);
            var row = rows.lookup (session.key);
            if (row == null) {
                row = new SessionRow (session);
                rows.insert (session.key, row);
                list.add (row);
            } else {
                row.update ();
            }
        }

        string[] gone = {};
        foreach (unowned var key in rows.get_keys ()) {
            if (!alive.contains (key)) {
                gone += key;
            }
        }
        foreach (var key in gone) {
            rows.lookup (key).destroy ();
            rows.remove (key);
        }

        list.invalidate_sort ();
        list.invalidate_headers ();
    }

    private int sort_rows (Gtk.ListBoxRow row_a, Gtk.ListBoxRow row_b) {
        var a = ((SessionRow) row_a).session;
        var b = ((SessionRow) row_b).session;
        if (a.category != b.category) {
            return (int) a.category - (int) b.category;
        }
        int64 diff;
        switch (a.category) {
            case Category.ATTENTION:
                // Longest wait first.
                diff = a.last_activity - b.last_activity;
                break;
            case Category.READY:
                diff = b.last_activity - a.last_activity;
                break;
            default:
                // Working sessions touch their transcript constantly; a stable order keeps rows from jumping.
                return strcmp (a.title, b.title);
        }
        return diff < 0 ? -1 : (diff > 0 ? 1 : strcmp (a.key, b.key));
    }

    private void update_header (Gtk.ListBoxRow row, Gtk.ListBoxRow? before) {
        var category = ((SessionRow) row).session.category;
        if (before != null && ((SessionRow) before).session.category == category) {
            row.set_header (null);
            return;
        }
        var label = new Gtk.Label (category.to_title ()) {
            halign = Gtk.Align.START,
            margin_start = 12,
            margin_top = before == null ? 6 : 12,
            margin_bottom = 3,
        };
        label.get_style_context ().add_class ("claude-header");
        row.set_header (label);
    }
}
