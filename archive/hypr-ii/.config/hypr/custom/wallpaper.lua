-- Animated wallpaper via mpvpaper (Noctalia mode only).
-- Like Luke Elrod's wallpaper_daemon.sh, but in Lua: pause the video while any visible
-- workspace has a fullscreen window (games, videos), resume when it doesn't.
-- Needs: mpvpaper, openbsd-netcat (nc -U). Noctalia's own wallpaper should be disabled
-- in its settings so it doesn't fight mpvpaper for the background layer.

local sock = os.getenv("XDG_RUNTIME_DIR") .. "/mpvpaper.sock"
local paused = nil
local generation = 0

local function mpv(cmd)
	hl.exec_cmd("printf '%s\\n' '" .. cmd .. "' | nc -NU " .. sock .. " >/dev/null 2>&1")
end

local function anyFullscreenVisible()
	for _, ws in ipairs(hl.get_workspaces()) do
		if ws.visible and ws.has_fullscreen then
			return true
		end
	end
	return false
end

-- Debounced: rapid fullscreen toggling only acts once things settle.
local function update()
	generation = generation + 1
	local mine = generation
	hl.timer(function()
		if mine ~= generation then
			return
		end
		local shouldPause = anyFullscreenVisible()
		if shouldPause ~= paused then
			paused = shouldPause
			mpv('{"command":["set_property","pause",' .. tostring(shouldPause) .. "]}")
		end
	end, { timeout = 150, type = "oneshot" })
end

hl.on("hyprland.start", function()
	if not is_file_exists(wallpaperVideo) then
		return
	end
	hl.exec_cmd(
		"mpvpaper -o 'no-audio loop hwdec=auto panscan=1.0 input-ipc-server=" .. sock .. "' '*' '" .. wallpaperVideo .. "'"
	)
end)

for _, event in ipairs({
	"window.fullscreen",
	"window.close",
	"window.destroy",
	"window.move_to_workspace",
	"workspace.active",
	"workspace.special_active",
	"monitor.focused",
}) do
	hl.on(event, update)
end
