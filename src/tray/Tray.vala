public class ClaudeAgents.Tray : Object {
    private class Entry {
        public string? label;
        public Session? session;

        public Entry (string? label, Session? session = null) {
            this.label = label;
            this.session = session;
        }
    }

    private Agents agents;
    private AppIndicator.Indicator indicator;
    private Gtk.Menu? menu;
    private GenericArray<Gtk.MenuItem> items;
    private string layout = "";
    private int shown_waiting = -1;

    construct {
        agents = new Agents (new GenericDesktop ());
        agents.notifier.app_icon = "claude-agents-tray";
        indicator = new AppIndicator.Indicator (
            "claude-agents-tray", "claude-agents-tray", AppIndicator.IndicatorCategory.APPLICATION_STATUS
        );
        indicator.set_attention_icon_full ("claude-agents-tray-attention", "A session needs you");

        agents.monitor.changed.connect (update);
        update ();
        agents.monitor.start ();
    }

    private void update () {
        var waiting = agents.monitor.count (Category.ATTENTION);
        if (waiting != shown_waiting) {
            shown_waiting = waiting;
            indicator.set_status (waiting > 0 ? AppIndicator.IndicatorStatus.ATTENTION : AppIndicator.IndicatorStatus.ACTIVE);
            // Plain ifs: valac 0.56 frees the string of a nested `?:` that mixes literals and allocated strings
            // before the call reads it.
            string label = "";
            string title = "Claude Agents";
            if (waiting == 1) {
                label = "1";
                title = "1 session needs you";
            } else if (waiting > 1) {
                label = waiting.to_string ();
                title = "%d sessions need you".printf (waiting);
            }
            indicator.set_label (label, "99");
            indicator.set_title (title);
        }

        var entries = list_entries ();
        var next = new StringBuilder ();
        foreach (var entry in entries) {
            next.append (entry.session != null ? "s" + entry.session.key : entry.label == null ? "-" : "l");
            next.append_c ('\n');
        }
        // Hosts redraw an open menu when it is replaced, so ages and usage are relabelled in place.
        if (next.str != layout) {
            layout = next.str;
            rebuild (entries);
            return;
        }
        for (var i = 0; i < entries.length; i++) {
            if (entries[i].label != null && items[i].label != entries[i].label) {
                items[i].label = entries[i].label;
            }
        }
    }

    private GenericArray<Entry> list_entries () {
        var monitor = agents.monitor;
        var entries = new GenericArray<Entry> ();
        if (monitor.error != null) {
            entries.add (new Entry (monitor.error));
        } else if (monitor.sessions.length == 0) {
            entries.add (new Entry ("No Claude Code sessions"));
        }
        foreach (var category in new Category[] { Category.ATTENTION, Category.READY, Category.WORKING }) {
            var first = true;
            foreach (var session in monitor.sessions) {
                if (session.category != category) {
                    continue;
                }
                if (first) {
                    entries.add (new Entry (category.to_title ()));
                    first = false;
                }
                entries.add (new Entry (describe (session), session));
            }
        }
        if (monitor.usage.available) {
            entries.add (new Entry (null));
            entries.add (new Entry (usage_line ("5-hour", monitor.usage.five_hour, monitor.usage.five_hour_resets_at)));
            entries.add (new Entry (usage_line ("Weekly", monitor.usage.seven_day, monitor.usage.seven_day_resets_at)));
        }
        return entries;
    }

    private void rebuild (GenericArray<Entry> entries) {
        var old = menu;
        menu = new Gtk.Menu ();
        items = new GenericArray<Gtk.MenuItem> ();

        foreach (var entry in entries) {
            Gtk.MenuItem item;
            if (entry.label == null) {
                item = new Gtk.SeparatorMenuItem ();
            } else if (entry.session != null) {
                var session = entry.session;
                item = new Gtk.MenuItem.with_label (entry.label);
                item.activate.connect (() => agents.activate (session));
            } else {
                item = new Gtk.MenuItem.with_label (entry.label);
                item.sensitive = false;
            }
            items.add (item);
            menu.append (item);
        }

        menu.append (new Gtk.SeparatorMenuItem ());
        var notifications = new Gtk.CheckMenuItem.with_label ("Notifications");
        notifications.active = agents.preferences.notifications;
        notifications.toggled.connect (() => agents.preferences.notifications = notifications.active);
        menu.append (notifications);

        var agent_view = new Gtk.MenuItem.with_label ("Open Agent View");
        agent_view.activate.connect (() => agents.open_agent_view ());
        menu.append (agent_view);

        var quit = new Gtk.MenuItem.with_label ("Quit");
        quit.activate.connect (() => GLib.Application.get_default ().quit ());
        menu.append (quit);

        menu.show_all ();
        indicator.set_menu (menu);
        // A menu belongs to its own popup window, so dropping the reference alone never frees it.
        if (old != null) {
            old.destroy ();
        }
    }

    private static string describe (Session session) {
        // A session with no conversation title yet is titled after its project; say it once.
        var text = session.title == session.project ? session.title : "%s · %s".printf (session.title, session.project);
        if (session.waiting_for != null) {
            text = "%s · %s".printf (text, session.waiting_for);
        }
        var age = Format.age (session.last_activity);
        return age != "" ? "%s · %s".printf (text, age) : text;
    }

    private static string usage_line (string name, double used, int64 resets_at) {
        var line = "%s %.0f%%".printf (name, Usage.current (used, resets_at));
        var remaining = Format.until (resets_at);
        return remaining != null ? "%s · resets in %s".printf (line, remaining) : line;
    }
}

int main (string[] args) {
    // Autostart and the app menu can both launch it; a second launch just exits.
    var app = new Gtk.Application ("io.github.rezk2ll.ClaudeAgentsTray", (ApplicationFlags) 0);
    ClaudeAgents.Tray? tray = null;
    app.activate.connect (() => {
        if (tray == null) {
            app.hold ();
            tray = new ClaudeAgents.Tray ();
        }
    });
    return app.run (args);
}
