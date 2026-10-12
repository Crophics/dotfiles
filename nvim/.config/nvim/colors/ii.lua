-- "ii" colorscheme: built from the illogical-impulse palette (see lua/ii_palette.lua), so Neovim
-- follows the wallpaper like the shell and kitty do. Interface colors come from the Material roles,
-- syntax colors from the same 16 ANSI colors kitty uses, so code matches the terminal.
local p = require("ii_palette").get()
if not p then
	-- no usable palette (shell not set up yet): fall back to gruvbox-material
	pcall(vim.cmd.colorscheme, "gruvbox-material")
	return
end

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
	vim.cmd("syntax reset")
end
vim.o.termguicolors = true
vim.o.background = p.dark and "dark" or "light"
vim.g.colors_name = "ii"

local c, t = p.c, p.t
local bg, fg = p.bg, p.fg

-- alpha of `a` over `b`
local function blend(a, b, alpha)
	local out = "#"
	for _, i in ipairs({ 2, 4, 6 }) do
		local x = tonumber(a:sub(i, i + 1), 16)
		local y = tonumber(b:sub(i, i + 1), 16)
		out = out .. string.format("%02x", math.floor(x * alpha + y * (1 - alpha) + 0.5))
	end
	return out
end

local float_bg = c.surface_container
local dim = c.on_surface_variant
local faint = c.outline
local line_nr = blend(fg, bg, 0.35)
local ghost = blend(fg, bg, 0.22)

local groups = {
	-- editor
	Normal = { fg = fg, bg = bg },
	NormalNC = { fg = fg, bg = bg },
	NormalFloat = { fg = fg, bg = float_bg },
	FloatBorder = { fg = faint, bg = float_bg },
	FloatTitle = { fg = c.primary, bg = float_bg, bold = true },
	Cursor = { fg = bg, bg = fg },
	lCursor = { fg = bg, bg = fg },
	TermCursor = { fg = bg, bg = fg },
	CursorLine = { bg = c.surface_container },
	CursorColumn = { bg = c.surface_container },
	ColorColumn = { bg = c.surface_container },
	Visual = { bg = c.primary_container },
	VisualNOS = { bg = c.primary_container },
	LineNr = { fg = line_nr },
	LineNrAbove = { fg = line_nr },
	LineNrBelow = { fg = line_nr },
	CursorLineNr = { fg = c.primary, bold = true },
	SignColumn = { fg = line_nr, bg = bg },
	FoldColumn = { fg = line_nr, bg = bg },
	Folded = { fg = dim, bg = float_bg },
	EndOfBuffer = { fg = bg },
	NonText = { fg = ghost },
	Whitespace = { fg = ghost },
	SpecialKey = { fg = ghost },
	Conceal = { fg = faint },
	MatchParen = { fg = c.on_primary_container, bg = c.primary_container, bold = true },
	Search = { fg = c.on_tertiary_container, bg = c.tertiary_container },
	IncSearch = { fg = c.on_primary, bg = c.primary },
	CurSearch = { fg = c.on_primary, bg = c.primary },
	Substitute = { fg = c.on_primary, bg = c.primary },
	Pmenu = { fg = fg, bg = float_bg },
	PmenuSel = { fg = c.on_primary_container, bg = c.primary_container },
	PmenuSbar = { bg = c.surface_container_high },
	PmenuThumb = { bg = faint },
	StatusLine = { fg = fg, bg = c.surface_container },
	StatusLineNC = { fg = faint, bg = c.surface_container },
	TabLine = { fg = dim, bg = c.surface_container },
	TabLineFill = { bg = c.surface_container },
	TabLineSel = { fg = c.on_primary_container, bg = c.primary_container, bold = true },
	WinBar = { fg = fg, bg = bg },
	WinBarNC = { fg = faint, bg = bg },
	WinSeparator = { fg = c.outline_variant },
	VertSplit = { fg = c.outline_variant },
	Title = { fg = c.primary, bold = true },
	Directory = { fg = t[4] },
	ErrorMsg = { fg = t[1], bold = true },
	WarningMsg = { fg = t[3] },
	MoreMsg = { fg = t[2] },
	ModeMsg = { fg = fg, bold = true },
	Question = { fg = t[4] },
	WildMenu = { fg = c.on_primary_container, bg = c.primary_container },

	-- syntax
	Comment = { fg = faint, italic = true },
	Constant = { fg = t[3] },
	String = { fg = t[2] },
	Character = { fg = t[2] },
	Number = { fg = t[3] },
	Boolean = { fg = t[3] },
	Float = { fg = t[3] },
	Identifier = { fg = fg },
	Function = { fg = t[4] },
	Statement = { fg = t[5] },
	Conditional = { fg = t[5] },
	Repeat = { fg = t[5] },
	Label = { fg = t[5] },
	Keyword = { fg = t[5] },
	Exception = { fg = t[5] },
	Operator = { fg = dim },
	PreProc = { fg = t[13] },
	Include = { fg = t[13] },
	Define = { fg = t[13] },
	Macro = { fg = t[13] },
	PreCondit = { fg = t[13] },
	Type = { fg = t[6] },
	StorageClass = { fg = t[6] },
	Structure = { fg = t[6] },
	Typedef = { fg = t[6] },
	Special = { fg = t[14] },
	SpecialChar = { fg = t[14] },
	Tag = { fg = t[14] },
	Delimiter = { fg = dim },
	SpecialComment = { fg = faint, bold = true },
	Debug = { fg = t[1] },
	Underlined = { fg = t[4], underline = true },
	Ignore = { fg = faint },
	Error = { fg = t[1] },
	Todo = { fg = bg, bg = t[3], bold = true },

	-- treesitter
	["@variable"] = { fg = fg },
	["@variable.builtin"] = { fg = t[9] },
	["@variable.parameter"] = { fg = c.tertiary },
	["@variable.member"] = { fg = c.secondary },
	["@property"] = { fg = c.secondary },
	["@constant.builtin"] = { fg = t[3], bold = true },
	["@module"] = { fg = t[3] },
	["@tag.attribute"] = { fg = c.secondary },
	["@tag.delimiter"] = { fg = dim },
	["@markup.heading.1"] = { fg = t[1], bold = true },
	["@markup.heading.2"] = { fg = t[3], bold = true },
	["@markup.heading.3"] = { fg = t[2], bold = true },
	["@markup.heading.4"] = { fg = t[4], bold = true },
	["@markup.heading.5"] = { fg = t[5], bold = true },
	["@markup.heading.6"] = { fg = t[6], bold = true },
	["@markup.strong"] = { bold = true },
	["@markup.italic"] = { italic = true },
	["@markup.strikethrough"] = { strikethrough = true },
	["@markup.link"] = { fg = t[4], underline = true },
	["@markup.link.url"] = { fg = t[4], underline = true },
	["@markup.raw"] = { fg = t[2], bg = float_bg },

	-- diagnostics
	DiagnosticError = { fg = t[1] },
	DiagnosticWarn = { fg = t[3] },
	DiagnosticInfo = { fg = t[4] },
	DiagnosticHint = { fg = t[6] },
	DiagnosticOk = { fg = t[2] },
	DiagnosticVirtualTextError = { fg = t[1], bg = blend(t[1], bg, 0.12) },
	DiagnosticVirtualTextWarn = { fg = t[3], bg = blend(t[3], bg, 0.12) },
	DiagnosticVirtualTextInfo = { fg = t[4], bg = blend(t[4], bg, 0.12) },
	DiagnosticVirtualTextHint = { fg = t[6], bg = blend(t[6], bg, 0.12) },
	DiagnosticUnderlineError = { undercurl = true, sp = t[1] },
	DiagnosticUnderlineWarn = { undercurl = true, sp = t[3] },
	DiagnosticUnderlineInfo = { undercurl = true, sp = t[4] },
	DiagnosticUnderlineHint = { undercurl = true, sp = t[6] },
	DiagnosticUnnecessary = { fg = faint },
	SpellBad = { undercurl = true, sp = t[1] },
	SpellCap = { undercurl = true, sp = t[3] },
	SpellLocal = { undercurl = true, sp = t[4] },
	SpellRare = { undercurl = true, sp = t[5] },

	-- diff / git
	DiffAdd = { bg = blend(t[2], bg, 0.18) },
	DiffDelete = { fg = blend(t[1], bg, 0.6), bg = blend(t[1], bg, 0.18) },
	DiffChange = { bg = blend(t[4], bg, 0.15) },
	DiffText = { bg = blend(t[4], bg, 0.38) },
	Added = { fg = t[2] },
	Removed = { fg = t[1] },
	Changed = { fg = t[4] },
	GitSignsAdd = { fg = t[2] },
	GitSignsChange = { fg = t[4] },
	GitSignsDelete = { fg = t[1] },

	-- plugins you use
	TelescopeNormal = { fg = fg, bg = float_bg },
	TelescopeBorder = { fg = faint, bg = float_bg },
	TelescopeTitle = { fg = c.primary, bold = true },
	TelescopePromptNormal = { fg = fg, bg = c.surface_container_high },
	TelescopePromptBorder = { fg = c.surface_container_high, bg = c.surface_container_high },
	TelescopeSelection = { fg = c.on_primary_container, bg = c.primary_container },
	TelescopeMatching = { fg = t[3], bold = true },
	BlinkCmpMenu = { link = "Pmenu" },
	BlinkCmpMenuSelection = { link = "PmenuSel" },
	BlinkCmpMenuBorder = { link = "FloatBorder" },
	BlinkCmpDoc = { link = "NormalFloat" },
	BlinkCmpDocBorder = { link = "FloatBorder" },
	BlinkCmpGhostText = { fg = faint, italic = true },
	BlinkCmpLabelMatch = { fg = t[3], bold = true },
	CopilotSuggestion = { fg = faint, italic = true },
	NotifyERRORBorder = { fg = t[1] },
	NotifyERRORTitle = { fg = t[1] },
	NotifyERRORIcon = { fg = t[1] },
	NotifyWARNBorder = { fg = t[3] },
	NotifyWARNTitle = { fg = t[3] },
	NotifyWARNIcon = { fg = t[3] },
	NotifyINFOBorder = { fg = t[4] },
	NotifyINFOTitle = { fg = t[4] },
	NotifyINFOIcon = { fg = t[4] },
	NotifyDEBUGBorder = { fg = faint },
	NotifyDEBUGTitle = { fg = faint },
	NotifyDEBUGIcon = { fg = faint },
	NotifyTRACEBorder = { fg = t[5] },
	NotifyTRACETitle = { fg = t[5] },
	NotifyTRACEIcon = { fg = t[5] },
	RenderMarkdownCode = { bg = float_bg },
	LazyNormal = { link = "NormalFloat" },
}

for name, spec in pairs(groups) do
	vim.api.nvim_set_hl(0, name, spec)
end

-- :terminal buffers (the agent terminal) use the same ANSI colors as kitty
for i = 0, 15 do
	vim.g["terminal_color_" .. i] = t[i]
end
