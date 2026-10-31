public class ClaudeAgents.Indicator : Wingpanel.Indicator {
    private const string RESOURCE_PATH = "/io/github/claude-agents-indicator";

    private Agents agents;
    private PanelWidget panel_widget;
    private PopoverWidget popover_widget;

    public Indicator () {
        Object (code_name: "claude-agents");
    }

    construct {
        Gtk.IconTheme.get_default ().add_resource_path (RESOURCE_PATH + "/icons");
        var provider = new Gtk.CssProvider ();
        provider.load_from_resource (RESOURCE_PATH + "/Indicator.css");
        Gtk.StyleContext.add_provider_for_screen (
            Gdk.Screen.get_default (), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );

        agents = new Agents (new PantheonDesktop ());
        agents.activated.connect (() => close ());
        var icon_theme = Gtk.IconTheme.get_default ();
        icon_theme.changed.connect (() => pick_notification_icon (icon_theme));
        pick_notification_icon (icon_theme);

        panel_widget = new PanelWidget (agents.monitor);
        popover_widget = new PopoverWidget (agents.monitor, agents.preferences);
        popover_widget.session_activated.connect ((session) => agents.activate (session));
        popover_widget.agent_view_requested.connect (() => {
            agents.open_agent_view ();
            close ();
        });

        visible = true;
        agents.monitor.start ();
    }

    public override Gtk.Widget get_display_widget () {
        return panel_widget;
    }

    public override Gtk.Widget? get_widget () {
        return popover_widget;
    }

    public override void opened () {
        agents.monitor.refresh.begin ();
    }

    public override void closed () {
    }

    // Claude Desktop installs a themed icon; without it, keep the terminal the sessions run in.
    private void pick_notification_icon (Gtk.IconTheme theme) {
        agents.notifier.app_icon = theme.has_icon ("claude-desktop") ? "claude-desktop" : "utilities-terminal";
    }
}

public Wingpanel.Indicator? get_indicator (Module module, Wingpanel.IndicatorManager.ServerType server_type) {
    if (server_type != Wingpanel.IndicatorManager.ServerType.SESSION) {
        return null;
    }
    return new ClaudeAgents.Indicator ();
}
