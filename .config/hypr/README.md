# Hyprland config guide

Hyprland reads `hyprland.lua` first. It loads the other files from the bottom of that file.
**Save a file and Hyprland reloads by itself.** Mistakes show up as an error bar at the top of the screen.

Check a config without applying it:

    Hyprland --verify-config -c ~/.config/hypr/hyprland.lua

Docs for everything: https://wiki.hypr.land (the Lua pages are under *Configuring*).

## Which file do I edit?

| I want to change...                                   | File           |
|-------------------------------------------------------|----------------|
| which app a key opens (terminal, browser, file manager) | `hyprland.lua`, the "MY PROGRAMS" block at the top |
| a keyboard shortcut                                   | `keybinds.lua` (one `hl.bind` per line) |
| programs that start at login                          | `hyprland.lua`, inside `hl.on("hyprland.start", ...)` |
| cursor theme and size                                 | `hyprland.lua`, the CURSOR block |
| touchpad, mouse, keyboard behaviour                   | `hyprland.lua`, the INPUT block |
| gaps, borders, border colours, rounding, blur, shadow, animations | `decorations.lua` |
| window opacity, per-app rules (always float, etc.)    | `rules.lua` |
| screen resolution, scale, second monitor              | `monitors.lua` |
| lock screen / idle timers                             | `hyprlock.conf`, `hypridle.conf` |

## Reading the Lua

- `-- text` is a comment. Hyprland ignores it. Put `--` in front of a line to turn it off.
- `hl.config({ general = { gaps_in = 2 } })` sets option `gaps_in` in the `general` section. The same names
  appear on the wiki's *Variables* page.
- `hl.bind("SUPER + E", exec(fileManager))` is: when I press Super+E, run the fileManager program.
- `local x = 5` makes a variable that only this file sees. A variable with no `local` (like `terminal`,
  `fileManager`) can be used from every file.
- `require("decorations")` runs `decorations.lua` from this folder.
- `hl.exec_cmd("...")` runs a shell command.

## What Settings (Super+I) still controls

Settings now covers the shell only: bar, popups, style (fonts and icon theme), network, bluetooth, audio,
power (idle lock/suspend) and storage. The Advanced page opens the config files in nvim.

Generated files (do not edit by hand; the Settings app overwrites them):
- `hypridle-user.conf`: idle timers, from Settings > Power.
- `~/.config/quickshell/state/*.json`: what the shell pages saved.

Super+O (the opacity menu) edits the `local opacity = ...` line in `rules.lua`. Keep that line in that shape.

## Useful commands

    hyprctl binds        every active shortcut
    hyprctl clients      open windows, with their class (for rules.lua)
    hyprctl monitors     screen names and modes (for monitors.lua)
    wev                  press a key to see its name (for keybinds.lua)
    hyprctl reload       reload the config by hand

Night light has no Settings page now: `~/.config/hypr/scripts/nightlight.py` (run it without arguments for usage).
