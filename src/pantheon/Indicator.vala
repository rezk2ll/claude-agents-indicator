public class ClaudeAgents.Indicator : Wingpanel.Indicator {
    private const string RESOURCE_PATH = "/io/github/claude-agents-indicator";

    private Desktop desktop;
    private SessionMonitor monitor;
    private Notifier notifier;
    private Preferences preferences;
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

        desktop = new Desktop ();
        preferences = new Preferences ();
        notifier = new Notifier ();
        monitor = new SessionMonitor (desktop);

        panel_widget = new PanelWidget (monitor);
        popover_widget = new PopoverWidget (monitor, preferences);
        popover_widget.session_activated.connect (activate_session);
        popover_widget.agent_view_requested.connect (() => {
            desktop.open_agent_view (monitor.claude_path);
            close ();
        });

        notifier.activated.connect ((key) => {
            var session = monitor.lookup (key);
            if (session != null) {
                activate_session (session);
            }
        });
        monitor.transitioned.connect (on_transition);
        monitor.removed.connect ((session) => notifier.withdraw (session.key));
        monitor.changed.connect (() => desktop.set_dock_badge (monitor.count (Category.ATTENTION)));

        visible = true;
        monitor.start ();
    }

    public override Gtk.Widget get_display_widget () {
        return panel_widget;
    }

    public override Gtk.Widget? get_widget () {
        return popover_widget;
    }

    public override void opened () {
        monitor.refresh.begin ();
    }

    public override void closed () {
    }

    private void on_transition (Session session, Category previous, bool is_new) {
        if (session.category == Category.ATTENTION) {
            if (preferences.notifications) {
                notifier.needs_you (session);
            }
        } else if (!is_new && session.category == Category.READY && previous == Category.WORKING) {
            if (preferences.notifications) {
                notifier.finished (session);
            } else {
                notifier.withdraw (session.key);
            }
        } else {
            notifier.withdraw (session.key);
        }
    }

    private void activate_session (Session session) {
        if (session.terminal_id != null) {
            desktop.focus_terminal_tab (session.terminal_id);
        } else if (session.window_uid != 0) {
            desktop.focus (session.window_uid);
        } else if (session.background) {
            desktop.open_terminal (session.cwd, { monitor.claude_path, "attach", session.id });
        }
        close ();
    }
}

public Wingpanel.Indicator? get_indicator (Module module, Wingpanel.IndicatorManager.ServerType server_type) {
    if (server_type != Wingpanel.IndicatorManager.ServerType.SESSION) {
        return null;
    }
    return new ClaudeAgents.Indicator ();
}
