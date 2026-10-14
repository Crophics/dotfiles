#!/usr/bin/env python3
"""Minimal BlueZ pairing agent for the Settings app.

Prints one request per line on stdout and reads the answer on stdin:
  CONFIRM <addr> <passkey>   -> YES | NO
  PIN <addr>                 -> PIN <code> | NO
  PASSKEY <addr>             -> KEY <number> | NO
  AUTH <addr>                -> YES | NO
  DISPLAY <addr> <code>      (informational)
  CANCEL                     (the request went away)
"""
import sys
import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

XML = """
<node><interface name="org.bluez.Agent1">
 <method name="Release"/>
 <method name="RequestPinCode"><arg type="o" direction="in"/><arg type="s" direction="out"/></method>
 <method name="DisplayPinCode"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
 <method name="RequestPasskey"><arg type="o" direction="in"/><arg type="u" direction="out"/></method>
 <method name="DisplayPasskey"><arg type="o" direction="in"/><arg type="u" direction="in"/><arg type="q" direction="in"/></method>
 <method name="RequestConfirmation"><arg type="o" direction="in"/><arg type="u" direction="in"/></method>
 <method name="RequestAuthorization"><arg type="o" direction="in"/></method>
 <method name="AuthorizeService"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
 <method name="Cancel"/>
</interface></node>"""

PATH = "/qs/bt/agent"
pending = None  # (kind, invocation)


def say(*parts):
    print(" ".join(str(p) for p in parts), flush=True)


def addr(dev):
    return str(dev).rsplit("dev_", 1)[-1].replace("_", ":")


def reject(inv):
    inv.return_dbus_error("org.bluez.Error.Rejected", "rejected")


def drop():
    global pending
    if pending:
        reject(pending[1])
        pending = None


def on_call(conn, sender, path, iface, method, params, inv):
    global pending
    a = params.unpack()
    if method in ("Release",):
        inv.return_value(None)
    elif method == "Cancel":
        drop(); say("CANCEL"); inv.return_value(None)
    elif method == "AuthorizeService":
        inv.return_value(None)
    elif method == "DisplayPinCode":
        say("DISPLAY", addr(a[0]), a[1]); inv.return_value(None)
    elif method == "DisplayPasskey":
        say("DISPLAY", addr(a[0]), "%06d" % a[1]); inv.return_value(None)
    elif method == "RequestConfirmation":
        drop(); pending = ("confirm", inv); say("CONFIRM", addr(a[0]), "%06d" % a[1])
    elif method == "RequestAuthorization":
        drop(); pending = ("auth", inv); say("AUTH", addr(a[0]))
    elif method == "RequestPinCode":
        drop(); pending = ("pin", inv); say("PIN", addr(a[0]))
    elif method == "RequestPasskey":
        drop(); pending = ("key", inv); say("PASSKEY", addr(a[0]))


def on_stdin(fd, cond):
    global pending
    line = sys.stdin.readline()
    if not line:
        loop.quit(); return False
    line = line.strip()
    if pending:
        kind, inv = pending
        pending = None
        word, _, rest = line.partition(" ")
        if kind in ("confirm", "auth") and word == "YES":
            inv.return_value(None)
        elif kind == "pin" and word == "PIN" and rest:
            inv.return_value(GLib.Variant("(s)", (rest,)))
        elif kind == "key" and word == "KEY" and rest.isdigit():
            inv.return_value(GLib.Variant("(u)", (int(rest),)))
        else:
            reject(inv)
    return True


bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
node = Gio.DBusNodeInfo.new_for_xml(XML)
bus.register_object(PATH, node.interfaces[0], on_call, None, None)
mgr = Gio.DBusProxy.new_sync(bus, 0, None, "org.bluez", "/org/bluez", "org.bluez.AgentManager1", None)
mgr.call_sync("RegisterAgent", GLib.Variant("(os)", (PATH, "KeyboardDisplay")), 0, -1, None)
mgr.call_sync("RequestDefaultAgent", GLib.Variant("(o)", (PATH,)), 0, -1, None)
say("READY")
GLib.io_add_watch(sys.stdin.fileno(), GLib.IO_IN, on_stdin)
loop = GLib.MainLoop()
try:
    loop.run()
finally:
    try:
        mgr.call_sync("UnregisterAgent", GLib.Variant("(o)", (PATH,)), 0, -1, None)
    except Exception:
        pass
