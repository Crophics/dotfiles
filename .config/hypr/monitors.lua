-- MONITORS.LUA
-- https://wiki.hypr.land/Configuring/Monitors/
-- Find your monitor names with:
--   hyprctl monitors

-- 1. First monitor
-- hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1.2 })
-- hl.monitor({ output = "HDMI-A-1", disabled = true })

-- 2. Second monitor
-- hl.monitor({ output = "eDP-1", disabled = true })
-- hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto", scale = 1.2 })

-- 3. Extend / Auto
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.2 }) 

-- 4. Duplicate
-- hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = 1.2 })
-- hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "0x0", scale = 1.2 })

-- 5. Second vertical monitor
-- hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "0x0", scale = 1.2 })
-- hl.monitor({ output = "eDP-1", mode = "preferred", position = "1920x0", scale = 1, transform = 1 })

-- Your laptop screen. This line wins over the generic rule above because it comes later.
-- scale 1.2 makes everything 20% bigger; mode is "WIDTHxHEIGHT@REFRESH".
hl.monitor({ output = "eDP-1", mode = "1920x1200@60.00", position = "0x0", scale = 1.2 })

-- HDMI port: mirror the laptop screen. If your screen shows up under another name (USB-C/DisplayPort
-- adapters are DP-1, DP-2...), run `hyprctl monitors` with it plugged in and copy the name.
hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto", scale = 1, mirror = "eDP-1" })

-- WORKSPACE RULES
-- https://wiki.hypr.land/Configuring/Workspace-Rules/
-- Workspaces 1-4 always exist (persistent), so they show in the bar even when empty.
-- With more monitors, pin a workspace to one with: monitor = "HDMI-A-1"

for i = 1, 4 do
    hl.workspace_rule({ workspace = tostring(i), default = true, persistent = true })
end
