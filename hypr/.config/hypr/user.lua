-- --- hypr/user.lua --------------------------------------------------------
-- Your Hyprland overrides, in Ryoku's `hl` Lua API. Loaded LAST, so anything
-- here wins over Ryoku's defaults and over Ryoku Settings. Updates never touch
-- it. (Ryoku's original header and examples: see `ryoku reset hypr/user.lua`.)
--
-- Keybinds: the old illogical-impulse key layout, ported onto Ryoku. Where an
-- old key collides with a Ryoku default, the Ryoku bind is unbound first and
-- the old one wins. Ryoku binds on keys the old layout never used are kept.

local HOME = os.getenv("HOME")

local function rebind(keys, dispatcher, opts)
	hl.unbind(keys)
	hl.bind(keys, dispatcher, opts)
end

-- Ryoku desktops are blocks of 10 workspaces; slot i of the current desktop
local function slot(i)
	local cur = hl.get_active_workspace().id
	return tostring(math.floor((cur - 1) / 10) * 10 + i)
end

--##! Shell
-- Super+Space launcher, Super+V clipboard, Super+Escape quick settings (power),
-- Super+L lock and Super+Q close are Ryoku defaults on the same keys.
rebind("SUPER + Period", hl.dsp.exec_cmd("pkill fuzzel || fuzzel-emoji copy"), { description = "Utilities: Emoji >> clipboard" })
rebind("CTRL + ALT + Delete", hl.dsp.global("ryoku:quicksettings"), { description = "Session: Power menu" })
rebind("SUPER + N", hl.dsp.global("ryoku:quicksettings"), { description = "Shell: Quick settings / notifications" })
rebind("SUPER + J", hl.dsp.global("ryoku:barToggle"), { description = "Shell: Toggle bar" })
rebind("SUPER + I", hl.dsp.exec_cmd("ryoku-shell hub open"), { description = "Shell: Ryoku Settings" })
rebind("CTRL + SUPER + T", hl.dsp.exec_cmd("ryogami wallpaper ui"), { description = "Shell: Change wallpaper" })

--##! Utilities
rebind(
	"SUPER + O",
	hl.dsp.exec_cmd(
		"pidof slurp || grim -g \"$(slurp)\" /tmp/ocr_image.png && tesseract /tmp/ocr_image.png stdout | wl-copy && rm /tmp/ocr_image.png"
	),
	{ description = "Utilities: Character recognition >> clipboard" }
)
rebind("SUPER + P", hl.dsp.exec_cmd("hyprpicker -a"), { description = "Utilities: Pick color #RRGGBB >> clipboard" })
rebind("Print", hl.dsp.exec_cmd("flock -n -o /tmp/ryoshot.lock qs -c ryoshot"), { description = "Utilities: Region screenshot" })
rebind(
	"SUPER + Print",
	hl.dsp.exec_cmd(
		"grim -o \"$(hyprctl activeworkspace -j | jq -r '.monitor')\" - | wl-copy && notify-send 'Screenshot' 'Fullscreen copied to clipboard' -a 'Screenshot'"
	),
	{ locked = true, description = "Utilities: Fullscreen screenshot >> clipboard" }
)

--##! Screen
local function zoom(value)
	local z = hl.get_config("cursor:zoom_factor") + value
	hl.config({ cursor = { zoom_factor = math.max(1.0, math.min(3.0, z)) } })
end
rebind("SUPER + Minus", function() zoom(-0.3) end, { repeating = true, description = "Screen: Zoom out" })
rebind("SUPER + Equal", function() zoom(0.3) end, { repeating = true, description = "Screen: Zoom in" })

--##! Media
local mediaNext = 'playerctl next || playerctl position `bc <<< "100 * $(playerctl metadata mpris:length) / 1000000 / 100"`'
rebind("SUPER + SHIFT + N", hl.dsp.exec_cmd(mediaNext), { locked = true, description = "Media: Next track" })
rebind("XF86AudioNext", hl.dsp.exec_cmd(mediaNext), { locked = true })
rebind("SUPER + SHIFT + B", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Media: Previous track" })
rebind("SUPER + SHIFT + P", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Media: Play/pause" })
rebind("ALT + XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"), { locked = true })
rebind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"), { locked = true })

--##! Window
rebind("SUPER + mouse:274", hl.dsp.window.drag(), { mouse = true })
rebind("SUPER + Semicolon", hl.dsp.layout("splitratio -0.1"), { repeating = true, description = "Window: Split ratio -" })
rebind("SUPER + Apostrophe", hl.dsp.layout("splitratio +0.1"), { repeating = true, description = "Window: Split ratio +" })
rebind("SUPER + ALT + Space", hl.dsp.window.float({ action = "toggle" }), { description = "Window: Float/Tile" })
-- Super+D maximize and Super+F fullscreen are Ryoku defaults on the same keys.

-- send to workspace N of this desktop and follow (Super+Alt+N sends and stays: Ryoku default)
for i = 1, 10 do
	local key = i % 10
	rebind("CTRL + SUPER + SHIFT + " .. key, function()
		hl.dispatch(hl.dsp.window.move({ workspace = slot(i), follow = true }))
	end, { description = "Window: Send to workspace " .. i .. " (follow)" })
end

-- scratchpad: send to / return from, stay put or follow
local function sendToScratchpad(follow)
	hl.dispatch(hl.dsp.window.move({ workspace = "special:special", follow = follow }))
end
local function returnFromScratchpad(follow)
	local current = hl.get_active_workspace().id
	hl.dispatch(hl.dsp.window.move({ workspace = tostring(current), follow = follow }))
end
rebind("SUPER + ALT + Up", function() sendToScratchpad(false) end, { description = "Window: Send to scratchpad" })
rebind("SUPER + ALT + Down", function() returnFromScratchpad(false) end, { description = "Window: Return from scratchpad" })
rebind("CTRL + SUPER + SHIFT + Up", function() sendToScratchpad(true) end, { description = "Window: Send to scratchpad (follow)" })
rebind("CTRL + SUPER + SHIFT + Down", function() returnFromScratchpad(true) end, { description = "Window: Return from scratchpad (follow)" })
rebind("CTRL + SUPER + Up", hl.dsp.exec_cmd("scratchpad-focus up"), { description = "Workspace: Enter scratchpad" })
rebind("CTRL + SUPER + Down", hl.dsp.exec_cmd("scratchpad-focus down"), { description = "Workspace: Exit scratchpad" })

-- previous / next workspace: focus, or send the window there
rebind("CTRL + SUPER + Left", hl.dsp.focus({ workspace = "r-1" }), { description = "Workspace: Focus left" })
rebind("CTRL + SUPER + Right", hl.dsp.focus({ workspace = "r+1" }), { description = "Workspace: Focus right" })
rebind("CTRL + SUPER + SHIFT + Left", hl.dsp.window.move({ workspace = "r-1" }), { description = "Window: Send to workspace left (follow)" })
rebind("CTRL + SUPER + SHIFT + Right", hl.dsp.window.move({ workspace = "r+1" }), { description = "Window: Send to workspace right (follow)" })
rebind("SUPER + ALT + Left", function()
	local here = hl.get_active_workspace().id
	hl.dispatch(hl.dsp.window.move({ workspace = "r-1", follow = false }))
	hl.dispatch(hl.dsp.focus({ workspace = tostring(here) }))
end, { description = "Window: Send to workspace left" })
rebind("SUPER + ALT + Right", function()
	local here = hl.get_active_workspace().id
	hl.dispatch(hl.dsp.window.move({ workspace = "r+1", follow = false }))
	hl.dispatch(hl.dsp.focus({ workspace = tostring(here) }))
end, { description = "Window: Send to workspace right" })

--##! Session
rebind("SUPER + SHIFT + L", hl.dsp.exec_cmd("systemctl suspend || loginctl suspend"), { locked = true, description = "Session: Sleep" })

--##! Apps
rebind("SUPER + Return", hl.dsp.exec_cmd("kitty -1"), { description = "App: Terminal" })
rebind("SUPER + E", hl.dsp.exec_cmd("nautilus"), { description = "App: File manager" })
rebind("SUPER + SHIFT + Return", hl.dsp.exec_cmd(HOME .. "/.local/bin/larp-terminal.sh"), { description = "App: Random LARP terminal" })
rebind("SUPER + W", hl.dsp.exec_cmd("zen-browser"), { description = "App: Browser" })
rebind("SUPER + C", hl.dsp.exec_cmd("codium"), { description = "App: Code editor" })
rebind("SUPER + X", hl.dsp.exec_cmd("gnome-text-editor"), { description = "App: Text editor" })
rebind("SUPER + S", hl.dsp.exec_cmd("spotify"), { description = "App: Spotify" })
rebind("SUPER + B", hl.dsp.exec_cmd("bitwarden-desktop"), { description = "App: Bitwarden" })
rebind("SUPER + K", hl.dsp.exec_cmd("gnome-calculator"), { description = "App: Calculator" })
rebind("CTRL + SUPER + V", hl.dsp.exec_cmd("pavucontrol-qt --tab 1"), { description = "App: Volume mixer" })
rebind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd("plasma-systemmonitor --page-name Processes"), { description = "App: Task manager" })
