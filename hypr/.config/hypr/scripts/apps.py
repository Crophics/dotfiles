#!/usr/bin/env python3
"""Installed apps and default-app handling for the Settings app.

  apps.py list                       every launchable app: id, name, exec, icon, mimes
  apps.py defaults                   current default app id for each category
  apps.py set <category> <app-id>    make an app the default for a category
"""
import configparser, glob, json, os, subprocess, sys

HOME = os.path.expanduser("~")
DIRS = ["/usr/share/applications", f"{HOME}/.local/share/applications",
        "/var/lib/flatpak/exports/share/applications", f"{HOME}/.local/share/flatpak/exports/share/applications"]

CATEGORIES = {
    "browser": ["x-scheme-handler/http", "x-scheme-handler/https", "text/html"],
    "files":   ["inode/directory"],
    "text":    ["text/plain", "text/markdown"],
    "image":   ["image/png", "image/jpeg", "image/gif", "image/webp", "image/svg+xml"],
    "video":   ["video/mp4", "video/x-matroska", "video/webm", "video/x-msvideo"],
    "audio":   ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav"],
    "pdf":     ["application/pdf"],
    "archive": ["application/zip", "application/x-tar", "application/gzip", "application/x-7z-compressed"],
    "email":   ["x-scheme-handler/mailto"],
}


def apps():
    seen, out = {}, []
    for d in DIRS:
        for path in glob.glob(f"{d}/**/*.desktop", recursive=True):
            app_id = os.path.relpath(path, d).replace("/", "-")
            if app_id in seen:
                continue
            cp = configparser.RawConfigParser(strict=False, interpolation=None)
            try:
                cp.read(path, encoding="utf-8")
                e = cp["Desktop Entry"]
            except Exception:
                continue
            if e.get("Type") != "Application" or e.get("NoDisplay", "").lower() == "true" or e.get("Hidden", "").lower() == "true":
                continue
            seen[app_id] = True
            out.append({"id": app_id, "name": e.get("Name", app_id), "exec": e.get("Exec", ""), "icon": e.get("Icon", ""),
                        "mimes": [m for m in e.get("MimeType", "").split(";") if m]})
    return sorted(out, key=lambda a: a["name"].lower())


def query(mime):
    return subprocess.run(["xdg-mime", "query", "default", mime], capture_output=True, text=True).stdout.strip()


def main():
    a = sys.argv[1:]
    cmd = a[0] if a else ""
    if cmd == "list":
        print(json.dumps(apps()))
    elif cmd == "defaults":
        out = {}
        for cat, mimes in CATEGORIES.items():
            out[cat] = query(mimes[0])
        print(json.dumps(out))
    elif cmd == "set" and len(a) == 3 and a[1] in CATEGORIES:
        subprocess.run(["xdg-mime", "default", a[2], *CATEGORIES[a[1]]], capture_output=True)
        if a[1] == "browser":
            subprocess.run(["xdg-settings", "set", "default-web-browser", a[2]], capture_output=True)
    else:
        sys.exit(__doc__)


main()
