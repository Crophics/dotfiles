# osd

Tiny volume/brightness popup for Wayland (Catppuccin Mocha, same size as the old quickshell one), written in Rust.
It draws with cairo + pango on a wlr-layer-shell overlay, at the display's fractional scale so it stays sharp.

- Build + install: `sh ~/.config/osd/build.sh`  (installs `~/.local/bin/osd`; the binary is not tracked).
  Crates are downloaded into a temporary folder that is deleted afterwards.
- Started by Hyprland's autostart. It waits on the pipe `$XDG_RUNTIME_DIR/osd.sock`.
- Show it with `~/.config/hypr/scripts/osd.sh vol 55`, `osd.sh vol 40 muted` or `osd.sh bri 15`.
- Look and feel (size, colours, fonts, margin, timeout) are constants at the top of `src/main.rs`; rebuild after editing.
