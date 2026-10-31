// The behavior every front end shares: polling, notifications and the dock badge.
public class ClaudeAgents.Agents : Object {
    public Desktop desktop { get; construct; }
    public SessionMonitor monitor { get; private set; }
    public Notifier notifier { get; private set; }
    public Preferences preferences { get; private set; }

    public Agents (Desktop desktop) {
        Object (desktop: desktop);
    }

    construct {
        preferences = new Preferences ();
        notifier = new Notifier ();
        monitor = new SessionMonitor (desktop);

        notifier.activated.connect ((key) => {
            var session = monitor.lookup (key);
            if (session != null) {
                activate (session);
            }
        });
        monitor.transitioned.connect (on_transition);
        monitor.removed.connect ((session) => notifier.withdraw (session.key));
        monitor.changed.connect (() => desktop.set_dock_badge (monitor.count (Category.ATTENTION)));
    }

    public void start () {
        monitor.start ();
    }

    public void activate (Session session) {
        desktop.activate (session, monitor.claude_path);
    }

    public void open_agent_view () {
        desktop.open_agent_view (monitor.claude_path);
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
}
