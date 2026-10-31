public class ClaudeAgents.PanelWidget : Gtk.Overlay {
    public SessionMonitor monitor { get; construct; }

    private Gtk.Image icon;
    private Gtk.Label badge;

    public PanelWidget (SessionMonitor monitor) {
        Object (monitor: monitor);
    }

    construct {
        icon = new Gtk.Image.from_icon_name ("claude-agents-symbolic", Gtk.IconSize.LARGE_TOOLBAR) {
            margin_end = 2,
            margin_top = 1,
        };
        icon.get_style_context ().add_class ("claude-panel-icon");

        badge = new Gtk.Label (null) {
            halign = Gtk.Align.END,
            valign = Gtk.Align.START,
            no_show_all = true,
        };
        badge.get_style_context ().add_class ("claude-badge");

        add (icon);
        add_overlay (badge);
        set_overlay_pass_through (badge, true);

        monitor.changed.connect (update);
    }

    private void update () {
        var attention = monitor.count (Category.ATTENTION);
        var ready = monitor.count (Category.READY);
        var working = monitor.count (Category.WORKING);

        icon.icon_name = attention > 0 ? "claude-agents-attention-symbolic" : "claude-agents-symbolic";
        unowned var style = icon.get_style_context ();
        if (working > 0 && attention == 0) {
            style.add_class ("working");
        } else {
            style.remove_class ("working");
        }

        badge.label = attention.to_string ();
        badge.visible = attention > 0;

        if (monitor.error != null) {
            tooltip_text = monitor.error;
        } else {
            var text = PopoverWidget.describe_counts (attention, ready, working);
            unowned var usage = monitor.usage;
            if (usage.available) {
                text += "\n5-hour %.0f%% · weekly %.0f%%".printf (
                    Usage.current (usage.five_hour, usage.five_hour_resets_at),
                    Usage.current (usage.seven_day, usage.seven_day_resets_at)
                );
            }
            tooltip_markup = "<b>Claude</b>\n%s".printf (Markup.escape_text (text));
        }
    }
}
