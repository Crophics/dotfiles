-- Personal Hyprland config, loaded last by Caelestia's hyprland.lua (wins over defaults).
-- Keep personal changes here and in hypr-vars.lua: everything else under ~/.config/hypr
-- is replaced when the dots are updated (`caelestia-dots-sync`).

local function rebind(keys, dispatcher, opts)
	hl.unbind(keys)
	hl.bind(keys, dispatcher, opts)
end

-- The fork's own pickers instead of upstream's fuzzel-based ones
rebind("SUPER + V", hl.dsp.global("caelestia:clipboard"))
rebind("SUPER + Period", hl.dsp.global("caelestia:emoji"))

-- Shell surfaces upstream doesn't bind
hl.bind("SUPER + Tab", hl.dsp.global("caelestia:workspaceOverview"))
hl.bind("SUPER + ALT + Tab", hl.dsp.global("caelestia:windowSwitcher"))
hl.bind("SUPER + F1", hl.dsp.global("caelestia:keybinds"))

-- From the old layout
hl.bind(
	"SUPER + O",
	hl.dsp.exec_cmd(
		"pidof slurp || grim -g \"$(slurp)\" /tmp/ocr_image.png && tesseract /tmp/ocr_image.png stdout | wl-copy && rm /tmp/ocr_image.png"
	)
)
hl.bind("SUPER + B", hl.dsp.exec_cmd("bitwarden-desktop"))
