-- ~/.config/hypr/hyprland.lua
-- Docs: https://wiki.hypr.land/Configuring/Start/

-- Cursor theme and size from Settings > Appearance (hypr/appearance.lua, written by scripts/appearance.py).
local oka, appearance = pcall(require, "appearance")
if not oka then appearance = {} end
local cursorTheme = appearance.cursor_theme or "Adwaita"
local cursorSize  = tostring(appearance.cursor_size or 24)

---- MY PROGRAMS ----

mainMod    = "SUPER"
terminal   = "kitty"
menu       = "rofi -show drun"
fileManager = "nautilus"
browser    = "zen-browser"

---- AUTOSTART ----

hl.on("hyprland.start", function()
    -- hl.exec_cmd("dunst") replaced with quickshell 
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("nm-applet")   -- Wi-Fi password prompts; the Settings panel steps aside while its dialog is open
    hl.exec_cmd("/usr/lib/hyprpolkitagent/hyprpolkitagent")
    hl.exec_cmd("hyprctl setcursor " .. cursorTheme .. " " .. cursorSize)
    hl.exec_cmd("sh -c 'sleep 5; hyprctl setcursor " .. cursorTheme .. " " .. cursorSize .. "'")   -- once more after the session has settled
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/start-hypridle.sh")

    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/nightlight.py daemon")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("~/.config/hypr/scripts/wallpaper-restore.sh")
    hl.exec_cmd("sleep 2 && qs")
end)

---- ENVIRONMENT VARIABLES ----

hl.env("XCURSOR_THEME", cursorTheme)
hl.env("XCURSOR_SIZE", cursorSize)
hl.env("HYPRCURSOR_THEME", cursorTheme)
hl.env("HYPRCURSOR_SIZE", cursorSize)

-- Use plain X cursor themes (Adwaita etc.). With hyprcursor on, Hyprland draws the only hyprcursor theme
-- installed (Bibata) at startup even when another theme is asked for, and the later `setcursor` can't
-- redraw it until some window sets a cursor shape.
hl.config({ cursor = { enable_hyprcursor = false } })
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("MOZ_ENABLE_WAYLAND", "1")

---- INPUT ----

hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0.5,
        accel_profile = "flat",
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            clickfinger_behavior = true,
        },
    },
})

-- LAYOUT
hl.config({
    dwindle = { preserve_split = true },
})
hl.config({
    master = { new_status = "master" },
})

-- MISC
hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
})

---- SPLIT-OUT FILES ----

require("monitors")
require("keybinds")
require("look")
require("rules")
pcall(require, "startup")   -- your own login apps (Settings > Apps, written by scripts/startup.py)
pcall(require, "options")   -- Settings app changes (hypr/options.lua, written by scripts/options.py); loaded last so it wins

