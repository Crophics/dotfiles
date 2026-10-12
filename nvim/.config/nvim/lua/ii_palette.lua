-- Loads the illogical-impulse palette that the shell generates from the wallpaper
-- (~/.local/state/quickshell/user/generated) and keeps Neovim's colorscheme in sync with it.
--   colors.json                    Material roles (surfaces, primary, ...), snake_case
--   terminal/kitty-theme.conf      the 16 ANSI colors + background/foreground kitty uses
--   material_colors.scss           $darkmode
-- Override the directory with $II_PALETTE_DIR (used for testing).
local M = {}
local uv = vim.uv or vim.loop

local function dir()
	if vim.env.II_PALETTE_DIR and vim.env.II_PALETTE_DIR ~= "" then
		return vim.env.II_PALETTE_DIR
	end
	local state = vim.env.XDG_STATE_HOME
	if not state or state == "" then
		state = vim.env.HOME .. "/.local/state"
	end
	return state .. "/quickshell/user/generated"
end

local function read(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local s = f:read("*a")
	f:close()
	return s
end

local function is_hex(s)
	return type(s) == "string" and s:match("^#%x%x%x%x%x%x$") ~= nil
end

--- Returns { c = material roles, t = {[0..15] = hex}, bg, fg, dark } or nil when the palette is missing/invalid.
function M.load()
	local d = dir()
	local json = read(d .. "/colors.json")
	local kitty = read(d .. "/terminal/kitty-theme.conf")
	if not json or not kitty then
		return nil
	end
	local ok, c = pcall(vim.json.decode, json)
	if not ok or type(c) ~= "table" or not is_hex(c.background) or not is_hex(c.primary) then
		return nil
	end

	local t, bg, fg = {}, nil, nil
	for line in kitty:gmatch("[^\r\n]+") do
		local key, val = line:match("^(%S+)%s+(#%x%x%x%x%x%x)%s*$")
		if key then
			local n = key:match("^color(%d+)$")
			if n then
				t[tonumber(n)] = val:lower()
			elseif key == "background" then
				bg = val:lower()
			elseif key == "foreground" then
				fg = val:lower()
			end
		end
	end
	for i = 0, 15 do
		if not t[i] then
			return nil -- unfilled template or truncated file: don't half-apply
		end
	end
	if not bg or not fg then
		return nil
	end

	local scss = read(d .. "/material_colors.scss") or ""
	local dark = scss:match("%$darkmode:%s*(%a+)")
	return { c = c, t = t, bg = bg, fg = fg, dark = not (dark and dark:lower() == "false") }
end

--- The palette currently in use (loads it on first use).
function M.get()
	if not M.palette then
		M.palette = M.load()
	end
	return M.palette
end

--- Re-read the palette and re-apply the colorscheme (no-op if the files are mid-write/invalid).
function M.reload()
	local p = M.load()
	if p then
		M.palette = p
		vim.cmd.colorscheme("ii")
	end
end

--- Reapply whenever the shell regenerates the palette (debounced: it writes several files in a row).
function M.watch()
	if M.handles then
		return
	end
	M.handles = {}
	local timer = uv.new_timer()
	local function on_event()
		timer:stop()
		timer:start(500, 0, vim.schedule_wrap(M.reload))
	end
	for _, path in ipairs({ dir(), dir() .. "/terminal" }) do
		local h = uv.new_fs_event()
		if h and h:start(path, {}, on_event) == 0 then
			table.insert(M.handles, h)
		end
	end
end

--- Apply the "ii" colorscheme and follow palette changes. Returns false if there is no usable palette.
function M.setup()
	local p = M.load()
	if not p then
		return false
	end
	M.palette = p
	vim.cmd.colorscheme("ii")
	M.watch()
	return true
end

return M
