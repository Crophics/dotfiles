-- ~/.config/hypr/rules.lua  --  per-app rules (opacity, floating) and layer rules (rofi blur, bar animation).

-- Docs: https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- To check class name, open the app and run:
-- hyprctl clients

hl.layer_rule({
    match = { namespace = "rofi" },
    blur = true,
    ignore_alpha = 0.15,
})

-- Windows are always fully opaque (1.0 = solid; try 0.9 for a little see-through)
hl.window_rule({
    match = { class = ".*" },
    opacity = "1.0 override",
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
hl.layer_rule({ match = { namespace = "rbar" }, animation = "slide top" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4, bezier = "pop", style = "popin 90%" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 6, bezier = "quick" })
