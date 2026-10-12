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
    opacity = "0.8 override",
})
hl.window_rule({
    match = { class = ".*", fullscreen = true },
    opacity = "1.0 override",
})

-- Never make photos and videos transparent: media players and image viewers,
-- and browser windows that are playing video (matched by page title).
-- These come after the global rule above, and Super+O only edits that first rule.
hl.window_rule({
    name = "opaque-media-apps",
    match = { class = "^(mpv|vlc|imv|feh|qimgv|swayimg|nomacs|org\\.gnome\\.Loupe|org\\.gnome\\.eog|org\\.kde\\.gwenview|org\\.kde\\.haruna|io\\.github\\.celluloid_player\\.Celluloid|org\\.xfce\\.ristretto|photoqt|gthumb)$" },
    opacity = "1.0 override",
})
hl.window_rule({
    name = "opaque-video-sites",
    match = { title = ".*(YouTube|Netflix|Twitch|Vimeo|Prime Video|Disney\\+|Crunchyroll|Picture-in-Picture).*" },
    opacity = "1.0 override",
})
hl.window_rule({
    name = "opaque-image-files",
    match = { title = ".*\\.(png|jpe?g|webp|gif|avif|mp4|mkv|webm|mov)( .*)?$" },
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
