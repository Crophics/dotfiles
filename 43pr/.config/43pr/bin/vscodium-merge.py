#!/usr/bin/env python3
"""Merge the generated Material Code colors into VSCodium's settings.json.

theme.py renders ~/.config/43pr/templates/vscodium-colors.json to ~/.cache/43pr/vscodium-colors.json and then
runs this script (target reload hook). Only the keys present in the generated file are replaced; every other
setting, and the key order, is left alone. Nothing is written if nothing changed."""
import glob, json, os, subprocess, sys, tempfile
from pathlib import Path

GEN = Path.home() / ".cache/43pr/vscodium-colors.json"
CFG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
SETTINGS = CFG / "VSCodium/User/settings.json"
STORAGE = CFG / "VSCodium/User/globalStorage/rakib13332.material-code/storage.json"
EXT_GLOB = str(Path.home() / ".vscode-oss/extensions/rakib13332.material-code-*/build/dark.json")


def codium_running():
    return subprocess.run(["pgrep", "-x", "codium"], capture_output=True).returncode == 0


def ensure_rebuild(settings):
    """Material Code only rebuilds its theme file when it sees a settings change while VSCodium is open (or on
    install). If the colors changed while VSCodium was closed, its built theme is stale, so reset the version
    marker it keeps: it then rebuilds on the next launch. Does nothing while VSCodium is running."""
    if codium_running() or not STORAGE.exists():
        return
    cols = settings.get("material-code.colors", {})
    want_bg = cols.get("background", "").lower()
    want_fg = cols.get("foreground", "").lower()
    for f in glob.glob(EXT_GLOB):
        try:
            built = json.loads(Path(f).read_text()).get("colors", {})
        except Exception:
            continue
        stale = (want_bg and built.get("editor.background", "").lower() != want_bg) or \
                (want_fg and built.get("editor.foreground", "").lower() != want_fg)
        if stale:
            try:
                st = json.loads(STORAGE.read_text())
            except Exception:
                st = {}
            if st.get("version") != "0":
                st["version"] = "0"   # any value other than the extension's own version triggers a rebuild
                STORAGE.write_text(json.dumps(st))
            return

def main():
    try:
        gen = json.loads(GEN.read_text())
    except Exception as e:
        print(f"vscodium-merge: cannot read {GEN}: {e}", file=sys.stderr); return 1
    try:
        cur = json.loads(SETTINGS.read_text()) if SETTINGS.exists() else {}
    except Exception as e:
        print(f"vscodium-merge: {SETTINGS} is not plain JSON ({e}); leaving it alone", file=sys.stderr); return 1
    new = dict(cur)
    new.update(gen)
    if new == cur:
        ensure_rebuild(cur)
        return 0
    SETTINGS.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=SETTINGS.parent, prefix=".settings-", suffix=".json")
    with os.fdopen(fd, "w") as f:
        json.dump(new, f, indent=2); f.write("\n")
    os.replace(tmp, SETTINGS)
    ensure_rebuild(new)
    return 0

if __name__ == "__main__":
    sys.exit(main())
