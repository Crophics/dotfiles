-- ~/.config/hypr/hyprland.lua
-- Docs: https://wiki.hypr.land/Configuring/Start/

---- MY PROGRAMS ----

mainMod    = "SUPER"
terminal   = "kitty"
menu       = "rofi -show drun"
fileManager = "nautilus"
browser    = "zen-browser"

---- AUTOSTART ----

hl.on("hyprland.start", function()
    -- hl.exec_cmd("dunst") replaced with quickshell 
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("/usr/lib/hyprpolkitagent/hyprpolkitagent")
    hl.exec_cmd("hyprctl setcursor Adwaita 24")
    hl.exec_cmd("sh -c 'sleep 5; hyprctl setcursor Adwaita 24'")   -- once more after the session has settled
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/start-hypridle.sh")

    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/nightlight.sh apply")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("~/.config/hypr/scripts/wallpaper-restore.sh")
    hl.exec_cmd("sleep 2 && qs")
end)

---- ENVIRONMENT VARIABLES ----

hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
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
pcall(require, "options")   -- Settings app changes (hypr/options.lua, written by scripts/options.py); loaded last so it wins

