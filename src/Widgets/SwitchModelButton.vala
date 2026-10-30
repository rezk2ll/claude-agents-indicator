public class ClaudeAgents.SwitchModelButton : Gtk.ToggleButton {
    public string text { get; construct; }

    public SwitchModelButton (string text) {
        Object (text: text);
    }

    construct {
        var label = new Gtk.Label (text) {
            ellipsize = Pango.EllipsizeMode.MIDDLE,
            halign = Gtk.Align.START,
            hexpand = true,
            max_width_chars = 25,
        };

        var button_switch = new Gtk.Switch () {
            can_focus = false,
            valign = Gtk.Align.CENTER,
        };

        var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        box.add (label);
        box.add (button_switch);
        add (box);

        get_style_context ().add_class (Gtk.STYLE_CLASS_MENUITEM);
        get_style_context ().add_class ("claude-switch");
        get_style_context ().remove_class (Gtk.STYLE_CLASS_BUTTON);
        bind_property ("active", button_switch, "active", BindingFlags.SYNC_CREATE | BindingFlags.BIDIRECTIONAL);
    }
}
