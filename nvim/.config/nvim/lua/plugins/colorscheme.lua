-- Colors follow the illogical-impulse palette (lua/ii_palette.lua + colors/ii.lua) and update live when the
-- shell regenerates it from the wallpaper. gruvbox-material stays installed as the fallback for when there is
-- no palette yet (fresh machine, shell not set up).
return {
	"sainnhe/gruvbox-material",
	lazy = false,
	priority = 1000,
	config = function()
		vim.g.gruvbox_material_enable_italic = true
		vim.g.gruvbox_material_background = "soft"
		if not require("ii_palette").setup() then
			vim.cmd.colorscheme("gruvbox-material")
		end
	end,
}
