-- Standard (Hyprland classic)
-- From ML4W dotfiles (GPL-3.0): https://github.com/mylinuxforwork/dotfiles, .config/hypr/conf/animations
-- Used unchanged; Settings > Windows > Animation speed scales every speed in it.

--------------------------------------------------------------------------------
-- Animation Master Switch
--------------------------------------------------------------------------------
hl.config({
    animations = {
        enabled = true,
    }
})

--------------------------------------------------------------------------------
-- Animation Curves (Bezier)
--------------------------------------------------------------------------------
hl.curve("myBezier", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })

--------------------------------------------------------------------------------
-- Animation Rules
--------------------------------------------------------------------------------
hl.animation({ leaf = "windows", enabled = true, speed = 7, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default" })
