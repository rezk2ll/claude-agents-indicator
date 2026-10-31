public class ClaudeAgents.UsageWidget : Gtk.Grid {
    public Usage usage { get; construct; }

    private Gtk.LevelBar five_hour_bar;
    private Gtk.Label five_hour_label;
    private Gtk.Label five_hour_reset;
    private Gtk.LevelBar seven_day_bar;
    private Gtk.Label seven_day_label;
    private Gtk.Label seven_day_reset;

    public UsageWidget (Usage usage) {
        Object (usage: usage);
    }

    construct {
        column_spacing = 12;
        row_spacing = 6;
        margin_start = 12;
        margin_end = 12;
        margin_top = 9;
        margin_bottom = 9;

        five_hour_bar = new_bar ();
        five_hour_label = new_value_label (4);
        five_hour_reset = new_value_label (7);
        seven_day_bar = new_bar ();
        seven_day_label = new_value_label (4);
        seven_day_reset = new_value_label (7);

        attach (new_name_label ("5-hour"), 0, 0);
        attach (five_hour_bar, 1, 0);
        attach (five_hour_label, 2, 0);
        attach (five_hour_reset, 3, 0);
        attach (new_name_label ("Weekly"), 0, 1);
        attach (seven_day_bar, 1, 1);
        attach (seven_day_label, 2, 1);
        attach (seven_day_reset, 3, 1);
    }

    public void update () {
        show_window (five_hour_bar, five_hour_label, five_hour_reset, usage.five_hour, usage.five_hour_resets_at);
        show_window (seven_day_bar, seven_day_label, seven_day_reset, usage.seven_day, usage.seven_day_resets_at);
    }

    private static void show_window (Gtk.LevelBar bar, Gtk.Label value, Gtk.Label reset, double used, int64 resets_at) {
        var current = Usage.current (used, resets_at);
        bar.value = (current / 100).clamp (0, 1);
        value.label = "%.0f%%".printf (current);
        var remaining = Format.until (resets_at);
        reset.label = remaining != null ? "↻ " + remaining : "";
        reset.tooltip_text = remaining != null ? "Resets in %s".printf (remaining) : null;
    }

    private static Gtk.LevelBar new_bar () {
        var bar = new Gtk.LevelBar.for_interval (0, 1) {
            hexpand = true,
            valign = Gtk.Align.CENTER,
        };
        // The default offsets read low values as alarming (battery semantics); usage is the opposite.
        bar.remove_offset_value (Gtk.LEVEL_BAR_OFFSET_LOW);
        bar.remove_offset_value (Gtk.LEVEL_BAR_OFFSET_HIGH);
        bar.remove_offset_value (Gtk.LEVEL_BAR_OFFSET_FULL);
        bar.add_offset_value ("usage-ok", 0.7);
        bar.add_offset_value ("usage-warn", 0.9);
        bar.add_offset_value ("usage-critical", 1.0);
        bar.get_style_context ().add_class ("claude-usage");
        return bar;
    }

    private static Gtk.Label new_name_label (string text) {
        var label = new Gtk.Label (text) {
            xalign = 0,
        };
        return label;
    }

    private static Gtk.Label new_value_label (int width) {
        var label = new Gtk.Label (null) {
            width_chars = width,
            xalign = 1,
        };
        label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        label.get_style_context ().add_class ("claude-time");
        return label;
    }
}
