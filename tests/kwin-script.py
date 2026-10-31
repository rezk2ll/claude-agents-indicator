#!/usr/bin/env python3
# Runs a snippet as a KWin script and prints what it passes to report (), for the KWin raise test.
# Usage: tests/kwin-script.py 'report (workspace.activeWindow.pid)'
import sys
import tempfile
from gi.repository import Gio, GLib

XML = """<node><interface name="io.github.rezk2ll.Test">
<method name="Report"><arg type="s" direction="in"/></method>
</interface></node>"""

bus = Gio.bus_get_sync(Gio.BusType.SESSION)
loop = GLib.MainLoop()
result = []


def on_call(conn, sender, path, iface, method, params, invocation):
    result.append(params.unpack()[0])
    invocation.return_value(None)
    loop.quit()


bus.register_object("/report", Gio.DBusNodeInfo.new_for_xml(XML).interfaces[0], on_call, None, None)
with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False) as script:
    script.write('function report (value) { callDBus ("%s", "/report", "io.github.rezk2ll.Test", "Report", String (value)); }\n'
                 % bus.get_unique_name())
    script.write(sys.argv[1])


def call(path, iface, method, args):
    return bus.call_sync("org.kde.KWin", path, iface, method, args, None, 0, 5000, None)


call("/Scripting", "org.kde.kwin.Scripting", "unloadScript", GLib.Variant("(s)", ("test-query",)))
call("/Scripting", "org.kde.kwin.Scripting", "loadScript", GLib.Variant("(ss)", (script.name, "test-query")))
call("/Scripting", "org.kde.kwin.Scripting", "start", None)
GLib.timeout_add_seconds(5, loop.quit)
loop.run()
print(result[0] if result else "NO REPLY")
