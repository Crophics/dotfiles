-- ~/.config/hypr/keybinds.lua
-- 43PR keybinds, remapped toward the old illogical-impulse layout.
-- Docs: https://wiki.hypr.land/Configuring/Basics/Binds/
--       https://wiki.hypr.land/Configuring/Basics/Dispatchers/

local home = os.getenv("HOME")
local menu = "rofi -show drun"

-- Apps
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("spotify"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("codium")) -- VSCodium
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("bitwarden-desktop"))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("hyprpicker -a")) -- Color picker
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd("kitty btop")) -- Task manager
hl.bind("CTRL + " .. mainMod .. " + V", hl.dsp.exec_cmd("pavucontrol")) -- Volume mixer

-- Launcher and shell panels
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("pgrep -x rofi >/dev/null && pkill -x rofi || " .. menu)) -- Toggle launcher
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("pgrep -x rofi >/dev/null && pkill -x rofi || cliphist list | rofi -dmenu -p '' | cliphist decode | wl-copy")) -- Clipboard history
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("qs ipc call powermenu toggle")) -- Power menu
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("qs ipc call settings toggle")) -- Settings
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("qs ipc call notifications toggle")) -- Notifications
hl.bind(mainMod .. " + J", hl.dsp.exec_cmd("qs ipc call bar toggle")) -- Toggle bar
hl.bind("CTRL + " .. mainMod .. " + T", hl.dsp.exec_cmd("qs -n -p ~/.config/quickshell/hyprquickpaper")) -- Wallpapers
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/opacity.sh")) -- Opacity
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("qs ipc call mediaosd settings")) -- OSD settings (volume popup)

-- Session
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock")) -- Lock screen
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/suspend.sh")) -- Suspend

-- Windows
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = 0 })) -- Fullscreen

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Toggle float window, center and resize
hl.bind(mainMod .. " + ALT + Space", function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))

    local w = hl.get_active_window()
    if w ~= nil and w.floating then
        local mon = hl.get_active_monitor()
        if mon ~= nil then
            local target_w = math.floor(mon.width * 0.7)
            local target_h = math.floor(mon.height * 0.7)

            -- absolute resize (relative = false), not a delta
            hl.dispatch(hl.dsp.window.resize({ x = target_w, y = target_h, relative = false }))

            local mon_x = mon.x or 0
            local mon_y = mon.y or 0
            local target_x = mon_x + math.floor((mon.width - target_w) / 2)
            local target_y = mon_y + math.floor((mon.height - target_h) / 2)

            -- absolute move to the centered position
            hl.dispatch(hl.dsp.window.move({ x = target_x, y = target_y, relative = false }))
        end
    end
end)

-- Special workspace (scratchpad)
local scratch = home .. "/.config/hypr/scripts/scratchpad.sh"
hl.bind(mainMod .. " + Grave", hl.dsp.exec_cmd(scratch .. " toggle")) -- Show / hide the special workspace
hl.bind(mainMod .. " + ALT + Up", hl.dsp.exec_cmd(scratch .. " send")) -- Send window to it
hl.bind(mainMod .. " + ALT + Down", hl.dsp.exec_cmd(scratch .. " return")) -- Bring window back
hl.bind(mainMod .. " + CTRL + SHIFT + Up", hl.dsp.exec_cmd(scratch .. " send follow")) -- Send window, follow it
hl.bind(mainMod .. " + CTRL + SHIFT + Down", hl.dsp.exec_cmd(scratch .. " return follow")) -- Bring window back, follow it

-- Focus and move with the arrow keys
hl.bind(mainMod .. " + Left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + Down", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + Up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "right" }))

hl.bind(mainMod .. " + SHIFT + Left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + Down", hl.dsp.window.move({ direction = "down" }))
hl.bind(mainMod .. " + SHIFT + Up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.window.move({ direction = "right" }))

-- Resize by pixel delta, repeating while held
hl.bind(mainMod .. " + CTRL + Left", hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + Right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + Up", hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + Down", hl.dsp.window.resize({ x = 0, y = 40, relative = true }), { repeating = true })

-- Workspaces 1-10, and move-to-workspace with SHIFT
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Screenshots
hl.bind("Print", hl.dsp.exec_cmd("sh -c 'file=" .. home .. "/Pictures/$(date +%s).png; grim -g \"$(slurp)\" \"$file\"; wl-copy < \"$file\"; qs ipc call screenshot notify \"$file\"'")) -- Area
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("sh -c 'file=" .. home .. "/Pictures/$(date +%s).png; grim \"$file\"; wl-copy < \"$file\"; qs ipc call screenshot notify \"$file\"'")) -- Full screen

-- GPU screen recorder (built-in display)
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(
    "bash -c 'PIDFILE=/tmp/osu-gsr.pid; if [ -f \"$PIDFILE\" ] && kill -0 \"$(cat \"$PIDFILE\")\" 2>/dev/null; then kill -INT \"$(cat \"$PIDFILE\")\"; rm -f \"$PIDFILE\"; else mkdir -p ~/Videos; gpu-screen-recorder -w eDP-1 -f 60 -a default_output -o ~/Videos/$(date +%Y-%m-%d_%H-%M-%S).mp4 & echo $! > \"$PIDFILE\"; fi'"
))

-- Zoom
local function zoomfunction(value)
    local zoomvalue = hl.get_config("cursor:zoom_factor")
    if (zoomvalue + value) > 1.5 then
        hl.config({ cursor = { zoom_factor = 1.5 } })
    elseif (zoomvalue + value) < 1.0 then
        hl.config({ cursor = { zoom_factor = 1.0 } })
    else
        hl.config({ cursor = { zoom_factor = zoomvalue + value } })
    end
end
hl.bind(mainMod .. " + mouse_down", function() zoomfunction(-0.5) end, { repeating = true })
hl.bind(mainMod .. " + mouse_up", function() zoomfunction(0.5) end, { repeating = true })
hl.bind(mainMod .. " + Minus", function() zoomfunction(-0.3) end, { repeating = true })
hl.bind(mainMod .. " + Equal", function() zoomfunction(0.3) end, { repeating = true })
-- Zoom with keypad
hl.bind(mainMod .. " + code:82", function() zoomfunction(-0.3) end, { repeating = true })
hl.bind(mainMod .. " + code:86", function() zoomfunction(0.3) end, { repeating = true })

-- Media, volume, brightness and mic keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("qs ipc call brightness up || brightnessctl s 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("qs ipc call brightness down || brightnessctl -n s 5%-"), { locked = true, repeating = true })

hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
