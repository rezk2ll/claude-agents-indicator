[DBus (name = "org.freedesktop.Notifications")]
public interface ClaudeAgents.NotificationServer : Object {
    [DBus (name = "Notify")]
    public abstract async uint32 send (
        string app_name, uint32 replaces_id, string app_icon, string summary, string body,
        string[] actions, HashTable<string, Variant> hints, int32 expire_timeout
    ) throws GLib.DBusError, GLib.IOError;

    public abstract async void close_notification (uint32 id) throws GLib.DBusError, GLib.IOError;

    public signal void action_invoked (uint32 id, string action_key);
}

public class ClaudeAgents.Notifier : Object {
    private const uchar URGENCY_NORMAL = 1;
    private const uchar URGENCY_CRITICAL = 2;

    public signal void activated (string session_key);

    // The core has no icon theme to look in, so each front end picks the icon.
    public string app_icon { get; set; default = "utilities-terminal"; }

    private NotificationServer? server = null;
    private HashTable<string, uint> ids = new HashTable<string, uint> (str_hash, str_equal);

    construct {
        connect_server.begin ();
    }

    private async void connect_server () {
        try {
            server = yield Bus.get_proxy<NotificationServer> (
                BusType.SESSION, "org.freedesktop.Notifications", "/org/freedesktop/Notifications"
            );
            server.action_invoked.connect (on_action_invoked);
        } catch (Error e) {
            warning ("Notification server unavailable: %s", e.message);
        }
    }

    public void needs_you (Session session) {
        var body = session.last_prompt != null
            ? "%s · “%s”".printf (session.project, session.last_prompt)
            : "%s · %s".printf (session.project, session.describe_status ());
        send.begin (session, "%s needs you".printf (session.title), body, URGENCY_CRITICAL);
    }

    public void finished (Session session) {
        send.begin (session, "%s is done".printf (session.title), "%s · your turn".printf (session.project), URGENCY_NORMAL);
    }

    public void withdraw (string session_key) {
        var id = ids.lookup (session_key);
        if (id == 0 || server == null) {
            return;
        }
        ids.remove (session_key);
        server.close_notification.begin (id, (obj, res) => {
            try {
                server.close_notification.end (res);
            } catch (Error e) {
                warning ("Cannot withdraw notification: %s", e.message);
            }
        });
    }

    private async void send (Session session, string summary, string body, uchar urgency) {
        if (server == null) {
            return;
        }
        string[] actions = { "default", "Show" };
        if (session.reachable) {
            actions += "show";
            actions += session.background ? "Attach" : "Show";
        }
        var hints = new HashTable<string, Variant> (str_hash, str_equal);
        hints.insert ("urgency", new Variant.byte (urgency));
        try {
            var id = yield server.send (
                "Claude", ids.lookup (session.key), app_icon, summary, body, actions, hints, -1
            );
            ids.insert (session.key, id);
        } catch (Error e) {
            warning ("Cannot send notification: %s", e.message);
        }
    }

    private void on_action_invoked (uint32 id, string action_key) {
        string? match = null;
        ids.foreach ((key, value) => {
            if (value == id) {
                match = key;
            }
        });
        if (match != null) {
            activated (match);
        }
    }
}
