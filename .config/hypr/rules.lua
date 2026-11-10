local okp, prefs = pcall(require, "prefs")
if not okp then prefs = {} end

-- Docs: https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- To check class name, open the app and run:
-- hyprctl clients

hl.layer_rule({
    match = { namespace = "rofi" },
    blur = true,
    ignore_alpha = 0.15,
})

-- Opacity rules for all windows except fullscreen
hl.window_rule({
    match = { class = ".*" },
    opacity = string.format("%.2f override", prefs.opacity or 0.9),
})
hl.window_rule({
    match = { class = ".*", fullscreen = true },
    opacity = "1.0 override",
})

--hl.window_rule({
--    name = "brave-opaque",
--    match = { class = "^brave-browser$" },
--    opacity = "1.0 override",
--})

hl.window_rule({
    match = { class = "kitty" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "float-pavucontrol",
    match = { class = "^(pavucontrol)$" },
    float = true,
})

hl.window_rule({
    name = "float-nm-connection-editor",
    match = { class = "^(nm-connection-editor)$" },
    float = true,
})

hl.window_rule({
    name = "float-blueman-manager",
    match = { class = "^(blueman-manager)$" },
    float = true,
})

hl.window_rule({
    name = "float-open-file",
    match = { title = "^(Open File)$" },
    float = true,
})

hl.window_rule({
    name = "float-save-file",
    match = { title = "^(Save File)$" },
    float = true,
})

-- Login handoff (see hyprland.lua autostart): wallpaper fades in, bar slides down from the top.
-- Other layers (rofi, popups) keep the default pop-in.
hl.layer_rule({ match = { namespace = "wallpaper" }, animation = "fade" })
hl.layer_rule({ match = { namespace = "qs-bar" }, animation = "slide top" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4, bezier = "pop", style = "popin 90%" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 6, bezier = "quick" })
