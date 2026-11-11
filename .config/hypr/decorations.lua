-- ~/.config/hypr/decorations.lua  --  how windows look: borders, gaps, rounding, blur, shadow, animations.
-- Edit a value, save, and Hyprland reloads by itself. Docs: https://wiki.hypr.land/Configuring/Variables/
-- (hl.config takes the same names as the wiki's sections: general, decoration, animations...)

-- Border colours. Fixed Catppuccin Mocha; the colours live in colors.lua.
local palette = require("colors")

hl.config({ render = { expand_undersized_textures = false } })

hl.config({
    general = {
        gaps_in = 2,             -- gap between windows (pixels)
        gaps_out = {             -- gap between windows and the screen edge
            top = 4,             -- small gap under the bar
            right = 0,
            bottom = 0,
            left = 0,
        },
        border_size = 0,         -- 0 = no border. Try 2 to see the coloured border again.
        col = { active_border = palette.active, inactive_border = palette.inactive },
        resize_on_border = true, -- drag a window edge to resize it
        allow_tearing = false,
        layout = "dwindle",      -- "dwindle", "master" or "scrolling" (tiling style)
    },
    decoration = {
        rounding = 0,            -- corner radius in pixels
        dim_strength = 0.25,     -- how much inactive windows are dimmed (when dimming is on)
        blur = {
            enabled = false,     -- true = frosted-glass blur behind transparent windows
            popups = true,
            size = 5,
            passes = 1,
            vibrancy = 0.2,
        },
        shadow = {
            enabled = false,
            range = 4,
            render_power = 3,
        },
    },
    animations = {
        enabled = true,          -- false = no animations at all
    },
})

---- Animations ----
-- "snappy" is the set defined below. To use a ready-made set from hypr/animation-presets/ instead,
-- put its file name here: "smooth", "slide", "moving", "standard", "material" or "fast".
local preset = "snappy"

-- Speeds are in tenths of a second: bigger = slower. Multiply them all with this to speed up or slow down.
local speed = 1.0
local function sp(x) return x * speed end

-- Curves: points are the two control points of a bezier. Preview shapes at https://cubic-bezier.com
hl.curve("snap",  { type = "bezier", points = { {0.16, 1.0}, {0.3, 1.0} } })    -- very fast start, for moves and workspaces
hl.curve("pop",   { type = "bezier", points = { {0.33, 1.0}, {0.68, 1.0} } })   -- ease-out cubic: visible motion, soft landing
hl.curve("quick", { type = "bezier", points = { {0.4, 0.0}, {0.6, 1.0} } })     -- even, for fades and borders

if preset ~= "snappy" then
    dofile(os.getenv("HOME") .. "/.config/hypr/animation-presets/" .. preset .. ".lua")
else
    -- A window opens from 80% size while fading in (about a quarter of a second), and closes the other way.
    hl.animation({ leaf = "windowsIn",   enabled = true, speed = sp(2.4), bezier = "pop",   style = "popin 80%" })
    hl.animation({ leaf = "windowsOut",  enabled = true, speed = sp(1.8), bezier = "pop",   style = "popin 85%" })
    hl.animation({ leaf = "windowsMove", enabled = true, speed = sp(2.4), bezier = "snap" })
    hl.animation({ leaf = "fadeIn",      enabled = true, speed = sp(1.8), bezier = "pop" })
    hl.animation({ leaf = "fadeOut",     enabled = true, speed = sp(1.5), bezier = "quick" })
    hl.animation({ leaf = "fade",        enabled = true, speed = sp(1.8), bezier = "quick" })
    hl.animation({ leaf = "border",      enabled = true, speed = sp(2.5), bezier = "quick" })
    hl.animation({ leaf = "workspaces",  enabled = true, speed = sp(2.4), bezier = "snap",  style = "slidefade 12%" })
    hl.animation({ leaf = "specialWorkspace", enabled = true, speed = sp(2.4), bezier = "snap", style = "slidefadevert 12%" })
end
