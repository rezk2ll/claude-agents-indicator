#!/usr/bin/env python3
# Minimal StatusNotifierWatcher + host: waits for the tray to register, then prints its status and menu labels.
import sys
from gi.repository import Gio, GLib

XML = """<node><interface name="org.kde.StatusNotifierWatcher">
<method name="RegisterStatusNotifierItem"><arg type="s" direction="in"/></method>
<method name="RegisterStatusNotifierHost"><arg type="s" direction="in"/></method>
<property name="RegisteredStatusNotifierItems" type="as" access="read"/>
<property name="IsStatusNotifierHostRegistered" type="b" access="read"/>
<property name="ProtocolVersion" type="i" access="read"/>
</interface></node>"""

loop = GLib.MainLoop()
items = []
bus = Gio.bus_get_sync(Gio.BusType.SESSION)


def labels(layout, depth=0, out=None):
    out = [] if out is None else out
    _id, props, children = layout
    if "label" in props:
        out.append(("  " * depth) + props["label"] + ("" if props.get("enabled", True) else "  [disabled]"))
    elif props.get("type") == "separator":
        out.append(("  " * depth) + "----")
    for child in children:
        labels(child.unpack() if hasattr(child, "unpack") else child, depth + 1, out)
    return out


def dump():
    if not items:
        print("NO ITEM REGISTERED")
        loop.quit()
        return False
    service, path = items[0]
    get = lambda p: bus.call_sync(service, path, "org.freedesktop.DBus.Properties", "Get",
                                  GLib.Variant("(ss)", ("org.kde.StatusNotifierItem", p)), None, 0, 2000, None).unpack()[0]
    print("Status:", get("Status"), "| IconName:", get("IconName"), "| AttentionIconName:", get("AttentionIconName"))
    menu = get("Menu")
    layout = bus.call_sync(service, menu, "com.canonical.dbusmenu", "GetLayout",
                           GLib.Variant("(iias)", (0, -1, [])), None, 0, 2000, None).unpack()[1]
    print("\n".join(labels(layout)))
    # An optional second argument clicks the first entry whose label starts with it, as a tray host would.
    if len(sys.argv) > 2:
        target = find(layout, sys.argv[2])
        print("Clicked:", target is not None)
        if target is not None:
            bus.call_sync(service, menu, "com.canonical.dbusmenu", "Event",
                          GLib.Variant("(isvu)", (target, "clicked", GLib.Variant("i", 0), 0)), None, 0, 2000, None)
        GLib.timeout_add_seconds(2, loop.quit)
        return False
    loop.quit()
    return False


def find(layout, prefix):
    item_id, props, children = layout
    if props.get("label", "").startswith(prefix):
        return item_id
    for child in children:
        found = find(child.unpack() if hasattr(child, "unpack") else child, prefix)
        if found is not None:
            return found
    return None


def on_call(conn, sender, path, iface, method, params, invocation):
    if method == "RegisterStatusNotifierItem":
        arg = params.unpack()[0]
        items.append((sender, arg) if arg.startswith("/") else (arg, "/StatusNotifierItem"))
        GLib.timeout_add_seconds(int(sys.argv[1]) if len(sys.argv) > 1 else 6, dump)
    invocation.return_value(None)


def on_get(conn, sender, path, iface, prop):
    return {"RegisteredStatusNotifierItems": GLib.Variant("as", [s for s, _ in items]),
            "IsStatusNotifierHostRegistered": GLib.Variant("b", True),
            "ProtocolVersion": GLib.Variant("i", 0)}[prop]


node = Gio.DBusNodeInfo.new_for_xml(XML)
bus.register_object("/StatusNotifierWatcher", node.interfaces[0], on_call, on_get, None)
Gio.bus_own_name_on_connection(bus, "org.kde.StatusNotifierWatcher", 0, None, None)
GLib.timeout_add_seconds(40, lambda: (print("TIMEOUT"), loop.quit()))
loop.run()
