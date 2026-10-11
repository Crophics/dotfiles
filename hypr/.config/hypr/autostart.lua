hl.on("hyprland.start", function()
	hl.exec_cmd("noctalia")
	hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")
	hl.exec_cmd("systemctl --user start hyprpolkitagent")

	-- idle -> lock (qylock) -> screen off -> suspend; see hypridle.conf
	hl.exec_cmd("hypridle")
	hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
	hl.exec_cmd("easyeffects --hide-window --service-mode")
	-- lock on login
	hl.exec_cmd("sleep 2 && loginctl lock-session")
end)
