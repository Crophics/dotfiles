-- ~/.config/hypr/hyprland.lua  --  the main file. Hyprland reads this first, then it loads the others (bottom).
-- Docs: https://wiki.hypr.land/Configuring/Start/
-- Save the file and Hyprland reloads by itself. Check for mistakes first with:
--   Hyprland --verify-config -c ~/.config/hypr/hyprland.lua
--
-- Where things live:
--   hyprland.lua  programs, input, autostart, environment (this file)
--   keybinds.lua  every keyboard shortcut
--   decorations.lua borders, gaps, rounding, blur, animations
--   rules.lua     per-app rules and window opacity
--   monitors.lua  screen resolution and scale
-- See README.md in this folder for more.

---- MY PROGRAMS ----
-- Names used by keybinds.lua. Change the program here and the key opens the new one.

mainMod           = "SUPER"
terminal          = "kitty"
menu              = "rofi -show drun"
fileManager       = "kitty -e yazi"
browser           = "zen-browser"

---- CURSOR ----
-- The cursor theme and size come from Settings > Style, which writes appearance.lua (the one
-- generated file left here). Edit the fallbacks after `or` if you want to set it by hand.

local oka, appearance = pcall(require, "appearance")
if not oka then appearance = {} end
local cursorTheme = appearance.cursor_theme or "Adwaita"
local cursorSize  = tostring(appearance.cursor_size or 24)

---- AUTOSTART ----
-- Each hl.exec_cmd("...") starts a program once, when Hyprland starts. Add your own at the bottom.

hl.on("hyprland.start", function()
    -- login handoff: Hyprland starts on black (the color the sign-in screen fades to),
    -- the wallpaper fades in first, then the bar slides down. One fixed wallpaper (no picker).
    hl.exec_cmd("swaybg -m fill -i '" .. os.getenv("HOME") .. "/Pictures/Wallpapers/dark mountain.png'")
    -- no notification daemon on purpose
    hl.exec_cmd("wl-paste --type text --watch cliphist store")    -- remember copied text (clipboard history)
    hl.exec_cmd("wl-paste --type image --watch cliphist store")   -- ...and copied images
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")   -- password prompts for admin actions
    hl.exec_cmd("hyprctl setcursor " .. cursorTheme .. " " .. cursorSize)
    hl.exec_cmd("sh -c 'sleep 5; hyprctl setcursor " .. cursorTheme .. " " .. cursorSize .. "'") -- once more after the session has settled
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/start-hypridle.sh")                  -- idle lock/suspend + lock before sleep (hyprlock)
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/nightlight.py daemon")               -- night light
    hl.exec_cmd("sleep 1.2 && qs") -- the quickshell bar; starts late so it slides down after the wallpaper fades in (rules.lua)

    -- Your own apps, one line each, for example:
    -- hl.exec_cmd("spotify-launcher")
end)

---- ENVIRONMENT VARIABLES ----
-- Variables every program started from Hyprland will see.

hl.env("XCURSOR_THEME", cursorTheme)
hl.env("XCURSOR_SIZE", cursorSize)
hl.env("HYPRCURSOR_THEME", cursorTheme)
hl.env("HYPRCURSOR_SIZE", cursorSize)

-- Use plain X cursor themes (Adwaita etc.). With hyprcursor on, Hyprland draws the only hyprcursor theme
-- installed (Bibata) at startup even when another theme is asked for, and the later `setcursor` can't
-- redraw it until some window sets a cursor shape.
hl.config({ cursor = { enable_hyprcursor = false } })

-- Draw only on the Intel iGPU (/dev/dri/igpu = udev symlink, /etc/udev/rules.d/71-igpu-symlink.rules).
-- The NVIDIA dGPU stays asleep unless an app is started with `prime-run`. Do not remove (suspend breaks).
hl.env("AQ_DRM_DEVICES", "/dev/dri/igpu")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3") -- Qt/KDE apps (EasyEffects) take the Catppuccin GTK colors
hl.env("MOZ_ENABLE_WAYLAND", "1")

---- INPUT ----
-- Keyboard, mouse and touchpad. All names are in the wiki: https://wiki.hypr.land/Configuring/Variables/#input

hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,             -- focus follows the mouse
        sensitivity = 0.5,            -- -1.0 (slowest) to 1.0 (fastest)
        accel_profile = "flat",       -- no mouse acceleration
        touchpad = {
            natural_scroll = true,
            tap_to_click = false,     -- true = tapping the touchpad clicks
            clickfinger_behavior = true,  -- two-finger click = right click, three = middle
        },
    },
})

---- TILING LAYOUTS ----
-- Which layout is used is set in decorations.lua (general.layout).

hl.config({
    dwindle = { preserve_split = true },
})
hl.config({
    master = { new_status = "master" },
})

---- MISC ----

hl.config({
    misc = {
        disable_hyprland_logo = true,
        background_color = 0xff000000,     -- pure black: same as the sign-in fade and the gap before Hyprland draws
        disable_splash_rendering = true,
        allow_session_lock_restore = true, -- a hung/crashed hyprlock can be replaced by a new one (run `hyprlock` from a TTY)
    },
})

---- THE OTHER FILES ----
-- require("name") runs name.lua from this folder.

require("monitors")
require("keybinds")
require("decorations")
require("rules")
