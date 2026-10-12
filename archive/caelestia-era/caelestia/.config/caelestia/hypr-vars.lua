-- Personal overrides for Caelestia's Hyprland variables (upstream's hypr/variables.lua).
-- Only what differs from the defaults; read by hyprland.lua before anything else.
-- Binds can be a string or a list of strings; a list REPLACES the default list.
--
-- Rule used for keys: the old (illogical-impulse) layout wins where keys collide, and the
-- Caelestia action that loses its key moves to a free one (marked "was ..." below).
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

	-- Behaviour
	sleepGestureCmd = "systemctl suspend", -- upstream: suspend-then-hibernate (no hibernation set up here)
	touchpadScrollFactor = 0.7,

	-- Old keys added next to Caelestia's own
	kbTerminal = { "SUPER + T", "SUPER + Return" },
	kbLauncher = { "SUPER + SUPER_L", "SUPER + Space" },
	kbSession = { "CTRL + ALT + Delete", "SUPER + Escape" },

	-- Caelestia actions moved off keys the old layout uses
	kbSpecialWs = "SUPER + grave", -- was Super+S (now Spotify)
	kbShowPanels = "SUPER + SHIFT + K", -- was Super+K (now calculator)
	kbCommunicationWs = "SUPER + SHIFT + D", -- was Super+D (now maximize)
	kbResizeWindow = "SUPER + SHIFT + X", -- was Super+X (now text editor)
	kbPinWindow = "SUPER + ALT + P", -- was Super+P (now color picker)

	-- Super+Alt+arrows are "send window to workspace/scratchpad" in the old layout, so window
	-- resizing keeps only the Super(+Shift)+Minus/Equal keys (zoom moved to Super+Alt+Minus/Equal)
	kbWindowDecreaseWidth = "SUPER + Minus",
	kbWindowIncreaseWidth = "SUPER + Equal",
	kbWindowDecreaseHeight = "SUPER + SHIFT + Minus",
	kbWindowIncreaseHeight = "SUPER + SHIFT + Equal",
}
