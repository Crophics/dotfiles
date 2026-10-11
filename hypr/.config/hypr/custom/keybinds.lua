-- This file will not be overwritten across dots-hyprland updates.
-- The file name is for the sake of organization and does not matter
-- See the corresponding files in ~/.config/hypr/hyprland for examples

-- Noctalia: take over the keys that ii (quickshell) owned. Same keys, Noctalia panels.
if desktopShell == "noctalia" then
	local ipc = "noctalia msg "
	local function rebind(keys, cmd, opts)
		hl.unbind(keys)
		hl.bind(keys, hl.dsp.exec_cmd(ipc .. cmd), opts)
	end

	rebind("SUPER + Space", "panel-toggle launcher", { description = "Shell: Launcher" })
	rebind("SUPER + V", "panel-toggle clipboard", { description = "Shell: Clipboard history" })
	rebind("SUPER + Period", "panel-toggle launcher /emo", { description = "Shell: Emoji picker" })
	rebind("SUPER + Escape", "panel-toggle session", { description = "Session: Power menu" })
	rebind("CTRL + ALT + Delete", "panel-toggle session", { description = "Session: Power menu" })
	rebind("SUPER + N", "panel-toggle control-center", { description = "Shell: Control center" })
	rebind("SUPER + J", "bar-toggle", { description = "Shell: Toggle bar" })
	rebind("SUPER + I", "settings-toggle", { description = "Shell: Settings" })
	rebind("SUPER + Comma", "settings-toggle", { description = "Shell: Settings" })
	rebind("Print", "screenshot-region", { locked = true, description = "Utilities: Region screenshot" })
	rebind("SUPER + SHIFT + S", "screenshot-region", { description = "Utilities: Region screenshot" })

	-- OSD-backed media keys
	rebind("XF86AudioRaiseVolume", "volume-up", { locked = true, repeating = true })
	rebind("XF86AudioLowerVolume", "volume-down", { locked = true, repeating = true })
	rebind("XF86AudioMute", "volume-mute", { locked = true })
	rebind("XF86AudioMicMute", "mic-mute", { locked = true })
	rebind("XF86MonBrightnessUp", "brightness-up", { locked = true, repeating = true })
	rebind("XF86MonBrightnessDown", "brightness-down", { locked = true, repeating = true })

	-- ii-only: wallpaper selector (wallpaper is mpvpaper now, see custom/variables.lua)
	hl.unbind("CTRL + SUPER + T")
end
