-- put former exec-once commands inside the func and former exec commands outside
hl.on("hyprland.start", function ()

    -- Bar, wallpaper
    hl.exec_cmd("$HOME/.config/hypr/hyprland/scripts/start_geoclue_agent.sh")
    hl.exec_cmd("qs -c $qsConfig")
    -- skwd-daemon not autostarted: wallpaper handling has reverted to ii's own
    -- native selector (CTRL+SUPER+ALT+T). skwd-wall is still installed and can
    -- be brought back with `skwd-daemon` + skwd's keybind if desired later.
    -- hl.exec_cmd("skwd-daemon")
    hl.exec_cmd("sleep 1 && hyprctl dispatch 'hl.dsp.global(\"quickshell:lock\")'")
    hl.exec_cmd("$HOME/.config/quickshell/ii/scripts/colors/firefox/watch-and-set-firefox-colors.sh")
    hl.exec_cmd("$HOME/.config/matugen/templates/kde/watch-and-fix-selection-contrast.sh")
    hl.exec_cmd("vmtouch -t /usr/lib/firefox")
    hl.exec_cmd("$HOME/.config/hypr/custom/scripts/__restore_video_wallpaper.sh")

    -- Core components (authentication, lock screen, notification daemon)
    -- hypridle is started from config/autostart.lua instead — don't duplicate here
    hl.exec_cmd("dbus-update-activation-environment --all")
    hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP") -- Some fix idk

    -- Audio
    hl.exec_cmd("easyeffects --hide-window --service-mode")

    -- Clipboard: history
    --hl.exec_cmd("wl-paste --watch cliphist store")
    hl.exec_cmd("wl-paste --type text --watch bash -c 'cliphist store && qs -c $qsConfig ipc call cliphistService update'")
    hl.exec_cmd("wl-paste --type image --watch bash -c 'cliphist store && qs -c $qsConfig ipc call cliphistService update'")

    -- Cursor
    hl.exec_cmd("hyprctl setcursor Adwaita 24")
end)
