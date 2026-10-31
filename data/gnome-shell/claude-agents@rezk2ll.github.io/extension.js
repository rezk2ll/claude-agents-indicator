// GNOME on Wayland lets no app raise another app's window, so the tray asks the shell to do it over D-Bus.
import Gio from 'gi://Gio';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const NAME = 'io.github.rezk2ll.ClaudeAgents.Shell';
const PATH = '/io/github/rezk2ll/ClaudeAgents/Shell';
const IFACE = `<node>
  <interface name="${NAME}">
    <method name="Activate">
      <arg type="ai" direction="in" name="pids"/>
      <arg type="b" direction="out" name="found"/>
    </method>
  </interface>
</node>`;

export default class ClaudeAgentsExtension extends Extension {
    enable() {
        this._object = Gio.DBusExportedObject.wrapJSObject(IFACE, this);
        this._object.export(Gio.DBus.session, PATH);
        this._name = Gio.bus_own_name_on_connection(Gio.DBus.session, NAME, Gio.BusNameOwnerFlags.NONE, null, null);
    }

    disable() {
        Gio.bus_unown_name(this._name);
        this._object.unexport();
        this._object = null;
    }

    // Activates the window of the nearest pid that has one.
    Activate(pids) {
        const windows = global.get_window_actors().map(actor => actor.meta_window);
        for (const pid of pids) {
            const match = windows.find(window => window.get_pid() === pid);
            if (match) {
                // A D-Bus call has no input event, so the shell's current time is the last event's, which Mutter
                // may count as older than the focused window's and refuse. A round trip gives a fresh one.
                Main.activateWindow(match, global.display.get_current_time_roundtrip());
                return true;
            }
        }
        return false;
    }
}
