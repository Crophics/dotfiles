-- Personal overrides for Caelestia's Hyprland variables (upstream's hypr/variables.lua).
-- Only what differs from the defaults; read by hyprland.lua before anything else.
-- Binds can be a string or a list of strings.
return {
	-- Apps
	terminal = "kitty -1",
	browser = "zen-browser",
	editor = "codium",
	fileExplorer = "nautilus",
	audioSettings = "pavucontrol-qt --tab 1",

	-- Cursor
	cursorTheme = "Bibata-Modern-Ice",
	cursorSize = 24,

	-- Keys from the old layout, added next to Caelestia's own
	kbTerminal = { "SUPER + T", "SUPER + Return" },
	kbLauncher = { "SUPER + SUPER_L", "SUPER + Space" },
}
