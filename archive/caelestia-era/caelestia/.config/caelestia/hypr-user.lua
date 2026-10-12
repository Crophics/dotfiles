-- Personal Hyprland config, loaded last by Caelestia's hyprland.lua (wins over defaults).
-- Keep personal changes here and in hypr-vars.lua: everything else under ~/.config/hypr
-- is replaced when the dots are updated (`caelestia-dots-sync`).
-- Ported from the old illogical-impulse / Noctalia / Ryoku setups (see archive/ in the dotfiles).

local HOME = os.getenv("HOME")

local function rebind(keys, dispatcher, opts)
	hl.unbind(keys)
	hl.bind(keys, dispatcher, opts)
end

--------------------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------------------
hl.config({
	input = {
		numlock_by_default = true,
		follow_mouse = 1,
		sensitivity = 0.3,
		accel_profile = "flat",
		touchpad = { clickfinger_behavior = true },
	},
	binds = { hide_special_on_workspace_change = true },
	cursor = { zoom_rigid = false, zoom_disable_aa = true },
	-- XWayland apps (Spotify, Steam, ...) render 1:1 instead of being stretched (blurry) to the
	-- monitor scale
	xwayland = { force_zero_scaling = true },
})

-- Laptop panel. Caelestia uses the preferred mode at scale 1; the old setups ran 1.2.
-- hl.monitor({ output = "eDP-1", mode = "1920x1200@60", position = "0x0", scale = 1.2 })

-- 3-finger pinch = fullscreen (4-finger swipe = workspace is already Caelestia's)
hl.gesture({ fingers = 3, direction = "pinch", action = "fullscreen" })

--------------------------------------------------------------------------------------------
-- Window rules
--------------------------------------------------------------------------------------------
-- Steam games on their own workspace
hl.window_rule({ match = { class = "^(steam_app.*|gamescope)$" }, workspace = "name:gaming" })

-- Floating dialogs and utilities
local floating = {
	{ title = "^(Open File|Select a File|Open Folder|Save As|File Upload|Library)(.*)$" },
	{ title = "^(.*)(wants to (save|open))$" },
	{ class = "^(org.pulseaudio.pavucontrol|pavucontrol|nm-connection-editor|blueberry\\.py)$" },
	{ class = "^(kvantummanager|qt[56]ct|nwg-look)$" },
	{ class = "^(org.gnome.Calculator)$" },
}
for _, m in ipairs(floating) do
	hl.window_rule({ match = m, float = true, center = true })
end

--------------------------------------------------------------------------------------------
-- Shell
--------------------------------------------------------------------------------------------
-- The fork's own pickers instead of upstream's fuzzel-based ones
rebind("SUPER + V", hl.dsp.global("caelestia:clipboard"))
rebind("SUPER + Period", hl.dsp.global("caelestia:emoji"))

hl.bind("SUPER + J", hl.dsp.exec_cmd("caelestia shell drawers toggle bar")) -- toggle the bar
hl.bind("SUPER + I", hl.dsp.exec_cmd("caelestia shell nexus open")) -- settings
hl.bind("CTRL + SUPER + T", hl.dsp.global("caelestia:wallpaper")) -- wallpaper picker

-- Shell surfaces upstream doesn't bind
hl.bind("SUPER + Tab", hl.dsp.global("caelestia:workspaceOverview"))
hl.bind("SUPER + ALT + Tab", hl.dsp.global("caelestia:windowSwitcher"))
hl.bind("SUPER + F1", hl.dsp.global("caelestia:keybinds"))

--------------------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------------------
hl.bind(
	"SUPER + O",
	hl.dsp.exec_cmd(
		"pidof slurp || grim -g \"$(slurp)\" /tmp/ocr_image.png && tesseract /tmp/ocr_image.png stdout | wl-copy && rm /tmp/ocr_image.png"
	)
) -- OCR a region to the clipboard
hl.bind("SUPER + P", hl.dsp.exec_cmd("hyprpicker -a")) -- color picker
hl.bind(
	"SUPER + Print",
	hl.dsp.exec_cmd(
		"grim -o \"$(hyprctl activeworkspace -j | jq -r '.monitor')\" - | wl-copy && notify-send 'Screenshot' 'Fullscreen copied to clipboard' -a 'Screenshot'"
	),
	{ locked = true }
)

-- Screen zoom
local function zoom(step)
	local z = hl.get_config("cursor:zoom_factor") + step
	hl.config({ cursor = { zoom_factor = math.max(1.0, math.min(3.0, z)) } })
end
hl.bind("SUPER + ALT + Minus", function() zoom(-0.3) end, { repeating = true })
hl.bind("SUPER + ALT + Equal", function() zoom(0.3) end, { repeating = true })

--------------------------------------------------------------------------------------------
-- Media
--------------------------------------------------------------------------------------------
hl.bind("SUPER + SHIFT + N", hl.dsp.global("caelestia:mediaNext"), { locked = true })
hl.bind("SUPER + SHIFT + B", hl.dsp.global("caelestia:mediaPrev"), { locked = true })
hl.bind("SUPER + SHIFT + P", hl.dsp.global("caelestia:mediaToggle"), { locked = true })
hl.bind("ALT + XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"), { locked = true })

--------------------------------------------------------------------------------------------
-- Windows and workspaces
--------------------------------------------------------------------------------------------
hl.bind("SUPER + D", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })) -- maximize
hl.bind("SUPER + Semicolon", hl.dsp.layout("splitratio -0.1"), { repeating = true })
hl.bind("SUPER + Apostrophe", hl.dsp.layout("splitratio +0.1"), { repeating = true })

-- Send window to workspace N and follow it (Super+Alt+N sends and stays: Caelestia's own)
for i = 1, 10 do
	hl.bind("CTRL + SUPER + SHIFT + " .. (i % 10), function()
		hl.dispatch(hl.dsp.window.move({ workspace = i, follow = true }))
	end)
end

-- Send window to the previous/next workspace and stay (Ctrl+Super+Shift+Left/Right follows: Caelestia's own)
local function send_adjacent(dir)
	local here = hl.get_active_workspace().id
	hl.dispatch(hl.dsp.window.move({ workspace = dir, follow = false }))
	hl.dispatch(hl.dsp.focus({ workspace = tostring(here) }))
end
hl.bind("SUPER + ALT + Left", function() send_adjacent("-1") end)
hl.bind("SUPER + ALT + Right", function() send_adjacent("+1") end)

-- Scratchpad (Caelestia's "special" workspace): send / return, staying put
-- (Ctrl+Super+Shift+Up/Down send/return and follow: Caelestia's own)
hl.bind("SUPER + ALT + Up", function()
	hl.dispatch(hl.dsp.window.move({ workspace = "special:special", follow = false }))
end)
hl.bind("SUPER + ALT + Down", function()
	local here = hl.get_active_workspace().id
	hl.dispatch(hl.dsp.window.move({ workspace = tostring(here), follow = false }))
end)
hl.bind("CTRL + SUPER + Up", hl.dsp.exec_cmd(HOME .. "/.local/bin/scratchpad-focus up"))
hl.bind("CTRL + SUPER + Down", hl.dsp.exec_cmd(HOME .. "/.local/bin/scratchpad-focus down"))

--------------------------------------------------------------------------------------------
-- Apps
--------------------------------------------------------------------------------------------
hl.bind("SUPER + X", hl.dsp.exec_cmd("gnome-text-editor"))
hl.bind("SUPER + S", hl.dsp.exec_cmd("spotify"))
hl.bind("SUPER + B", hl.dsp.exec_cmd("bitwarden-desktop"))
hl.bind("SUPER + K", hl.dsp.exec_cmd("gnome-calculator"))
hl.bind("CTRL + SUPER + V", hl.dsp.exec_cmd("pavucontrol-qt --tab 1"))
hl.bind("SUPER + SHIFT + Return", hl.dsp.exec_cmd(HOME .. "/.local/bin/larp-terminal.sh"))
