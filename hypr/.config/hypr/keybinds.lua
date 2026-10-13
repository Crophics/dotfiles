-- ~/.config/hypr/keybinds.lua
-- Key bindings are data, not code: every rebindable shortcut is an entry in
-- keybind-defaults.json, merged with your changes from Settings > Keybinds into binds.lua
-- (see scripts/apply-keybinds.sh). This file maps each entry id to what it does, then binds them.
-- Fixed bindings that are not rebindable (mouse, zoom, media keys) are at the bottom.
-- Docs: https://wiki.hypr.land/Configuring/Basics/Binds/
--       https://wiki.hypr.land/Configuring/Basics/Dispatchers/

local home = os.getenv("HOME")
local scratch = home .. "/.config/hypr/scripts/scratchpad.sh"
local exec = hl.dsp.exec_cmd

-- Toggle a rofi menu: a second press closes it.
local function rofi(cmd) return exec("pgrep -x rofi >/dev/null && pkill -x rofi || " .. cmd) end

local function float_and_center()
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
end

-- id -> { action, options }. `opts` is passed to hl.bind (e.g. repeating while held).
local actions = {
    -- Apps
    ["terminal"]  = { exec(terminal) },
    ["files"]     = { exec(fileManager) },
    ["browser"]   = { exec(browser) },
    ["spotify"]   = { exec("spotify") },
    ["code"]      = { exec("codium") },
    ["bitwarden"] = { exec("bitwarden-desktop") },
    ["picker"]    = { exec("hyprpicker -a") },
    ["taskmgr"]   = { exec("kitty btop") },
    ["mixer"]     = { exec("pavucontrol") },

    -- Launcher and shell panels
    ["launcher"]       = { rofi(menu) },
    ["clipboard"]      = { rofi("cliphist list | rofi -dmenu -p '' | cliphist decode | wl-copy") },
    ["powermenu"]      = { exec("qs ipc call powermenu toggle") },
    ["settings"]       = { exec("qs ipc call settings toggle") },
    ["notifications"]  = { exec("qs ipc call notifications toggle") },
    ["togglebar"]      = { exec("qs ipc call bar toggle") },
    ["wallpapers"]     = { exec("qs -n -p ~/.config/quickshell/hyprquickpaper") },
    ["opacity"]        = { exec(home .. "/.config/hypr/scripts/opacity.sh") },
    ["windowsettings"] = { exec("qs ipc call settings page Windows") },
    ["popupsettings"]  = { exec("qs ipc call mediaosd settings") },

    -- Session
    ["lock"]    = { exec("hyprlock") },
    ["suspend"] = { exec(home .. "/.config/hypr/scripts/suspend.sh") },

    -- Windows
    ["close"]       = { hl.dsp.window.close() },
    ["fullscreen"]  = { hl.dsp.window.fullscreen({ mode = 0 }) },
    ["floatcenter"] = { float_and_center },

    -- Special workspace (scratchpad)
    ["scratch-toggle"]        = { exec(scratch .. " toggle") },
    ["scratch-send"]          = { exec(scratch .. " send") },
    ["scratch-return"]        = { exec(scratch .. " return") },
    ["scratch-send-follow"]   = { exec(scratch .. " send follow") },
    ["scratch-return-follow"] = { exec(scratch .. " return follow") },

    -- Focus, move and resize with the arrow keys
    ["focus-left"]  = { hl.dsp.focus({ direction = "left" }) },
    ["focus-down"]  = { hl.dsp.focus({ direction = "down" }) },
    ["focus-up"]    = { hl.dsp.focus({ direction = "up" }) },
    ["focus-right"] = { hl.dsp.focus({ direction = "right" }) },

    ["move-left"]  = { hl.dsp.window.move({ direction = "left" }) },
    ["move-down"]  = { hl.dsp.window.move({ direction = "down" }) },
    ["move-up"]    = { hl.dsp.window.move({ direction = "up" }) },
    ["move-right"] = { hl.dsp.window.move({ direction = "right" }) },

    -- Resize by pixel delta, repeating while held
    ["resize-left"]  = { hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true } },
    ["resize-right"] = { hl.dsp.window.resize({ x = 40, y = 0, relative = true }), { repeating = true } },
    ["resize-up"]    = { hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true } },
    ["resize-down"]  = { hl.dsp.window.resize({ x = 0, y = 40, relative = true }), { repeating = true } },

    -- Screenshots and recording
    ["shot-area"] = { exec("sh -c 'file=" .. home .. "/Pictures/$(date +%s).png; grim -g \"$(slurp)\" \"$file\"; wl-copy < \"$file\"; qs ipc call screenshot notify \"$file\"'") },
    ["shot-full"] = { exec("sh -c 'file=" .. home .. "/Pictures/$(date +%s).png; grim \"$file\"; wl-copy < \"$file\"; qs ipc call screenshot notify \"$file\"'") },
    ["record"]    = { exec("bash -c 'PIDFILE=/tmp/osu-gsr.pid; if [ -f \"$PIDFILE\" ] && kill -0 \"$(cat \"$PIDFILE\")\" 2>/dev/null; then kill -INT \"$(cat \"$PIDFILE\")\"; rm -f \"$PIDFILE\"; else mkdir -p ~/Videos; gpu-screen-recorder -w eDP-1 -f 60 -a default_output -o ~/Videos/$(date +%Y-%m-%d_%H-%M-%S).mp4 & echo $! > \"$PIDFILE\"; fi'") },
}

-- "SUPER + SHIFT + L"; an empty modifier list gives just the key.
local function combo(mods, key)
    local parts = {}
    for _, m in ipairs(mods) do parts[#parts + 1] = m end
    parts[#parts + 1] = key
    return table.concat(parts, " + ")
end

local ok, list = pcall(require, "binds")          -- your settings (generated, not tracked)
if not ok then list = require("binds-default") end -- the defaults that ship with the config

for _, b in ipairs(list) do
    if b.enabled and b.key ~= "" then
        if b.command then
            hl.bind(combo(b.mods, b.key), exec(b.command))        -- custom command
        elseif b.modsOnly then
            -- Workspaces 1-10: the number row is fixed, the modifiers are yours. 0 is workspace 10.
            for i = 1, 10 do
                local key = tostring(i % 10)
                if b.id == "ws-focus" then
                    hl.bind(combo(b.mods, key), hl.dsp.focus({ workspace = i }))
                elseif b.id == "ws-move" then
                    hl.bind(combo(b.mods, key), hl.dsp.window.move({ workspace = i }))
                end
            end
        elseif actions[b.id] then
            hl.bind(combo(b.mods, b.key), actions[b.id][1], actions[b.id][2])
        end
    end
end

---- Fixed bindings (not rebindable) ----

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

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

-- A submap with no real bindings. Settings > Keybinds switches to it while it records a new
-- shortcut, so that pressing a combo that is already bound does not run its action. (A submap
-- needs at least one bind to exist; this key is one nobody has.)
hl.define_submap("capture", function()
    hl.bind("XF86Launch9", hl.dsp.submap("reset"))
end)
