-- ~/.config/hypr/keybinds.lua  --  every keyboard shortcut, one per line.
--
-- Reading a bind:
--     hl.bind("SUPER + E", exec(fileManager))
--             ^ keys        ^ what to do
-- Modifiers: SUPER, SHIFT, CTRL, ALT. Join with " + ". The last part is the key (E, Return, Left, F5...).
-- To rebind, change the keys in quotes. To remove a shortcut, delete the line (or put -- in front of it).
-- To list key names: run `wev` and press the key. To see what is bound now: `hyprctl binds`.
-- Docs: https://wiki.hypr.land/Configuring/Basics/Binds/
--       https://wiki.hypr.land/Configuring/Basics/Dispatchers/

local home = os.getenv("HOME")
local scripts = home .. "/.config/hypr/scripts"
local exec = hl.dsp.exec_cmd   -- run a shell command

-- Toggle a rofi menu: pressing the key again closes it.
local function rofi(cmd) return exec("pgrep -x rofi >/dev/null && pkill -x rofi || " .. cmd) end

-- Float the focused window and centre it at 70% of the screen (or tile it again).
local function float_and_center()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))

    local w = hl.get_active_window()
    if w ~= nil and w.floating then
        local mon = hl.get_active_monitor()
        if mon ~= nil then
            local target_w = math.floor(mon.width * 0.7)
            local target_h = math.floor(mon.height * 0.7)
            hl.dispatch(hl.dsp.window.resize({ x = target_w, y = target_h, relative = false }))   -- absolute size
            local target_x = (mon.x or 0) + math.floor((mon.width - target_w) / 2)
            local target_y = (mon.y or 0) + math.floor((mon.height - target_h) / 2)
            hl.dispatch(hl.dsp.window.move({ x = target_x, y = target_y, relative = false }))     -- absolute position
        end
    end
end

---- Apps (the program names are set at the top of hyprland.lua) ----
hl.bind("SUPER + T",            exec(terminal))   -- terminal
hl.bind("SUPER + E",            exec(fileManager))   -- file manager
hl.bind("SUPER + W",            exec(browser))   -- browser
hl.bind("SUPER + S",            exec(home .. "/.local/bin/spotify-spotx"))   -- Spotify
hl.bind("SUPER + C",            exec("kitty nvim"))   -- nvim
hl.bind("SUPER + B",            exec("bitwarden-desktop"))   -- Bitwarden
hl.bind("SUPER + P",            exec("hyprpicker -a"))               -- colour picker, copies the colour
hl.bind("CTRL + SHIFT + Escape", exec("kitty btop"))                 -- task manager
hl.bind("CTRL + SUPER + V",     exec("pavucontrol"))                 -- volume mixer

---- Menus ----
hl.bind("SUPER + Space",        rofi(menu))                          -- app launcher
hl.bind("SUPER + V",            rofi("cliphist list | rofi -dmenu -p '' | cliphist decode | wl-copy"))   -- clipboard history
hl.bind("SUPER + Escape",       rofi(scripts .. "/powermenu.sh"))   -- power menu
hl.bind("SUPER + K",            rofi(scripts .. "/keybinds.sh"))     -- cheat sheet of these keys
hl.bind("SUPER + O",            exec(scripts .. "/opacity.sh"))      -- window opacity menu
hl.bind("SUPER + CTRL + P",     exec(scripts .. "/powerprofile.sh")) -- power profile menu
hl.bind("SUPER + I",            exec("qs ipc call settings toggle")) -- Settings window
hl.bind("SUPER + J",            exec("qs ipc call bar toggle"))      -- show/hide the bar
hl.bind("SUPER + SHIFT + M",    exec("qs ipc call mediaosd settings"))   -- media popup settings

---- Session ----
hl.bind("SUPER + L",            exec("loginctl lock-session"))       -- lock the screen (hypridle runs qylock)
hl.bind("SUPER + SHIFT + L",    exec(home .. "/.config/qylock/suspend.sh"))   -- suspend (screen off, lock, then sleep)

---- Windows ----
hl.bind("SUPER + Q",            hl.dsp.window.close())   -- close window
hl.bind("SUPER + F",            hl.dsp.window.fullscreen({ mode = 0 }))   -- fullscreen
hl.bind("SUPER + ALT + Space",  float_and_center)   -- float + centre window

-- Focus (Super), move (Super+Shift) and resize (Super+Ctrl) with the arrow keys.
hl.bind("SUPER + Left",         hl.dsp.focus({ direction = "left" }))   -- focus left
hl.bind("SUPER + Down",         hl.dsp.focus({ direction = "down" }))   -- focus down
hl.bind("SUPER + Up",           hl.dsp.focus({ direction = "up" }))   -- focus up
hl.bind("SUPER + Right",        hl.dsp.focus({ direction = "right" }))   -- focus right

hl.bind("SUPER + SHIFT + Left",  hl.dsp.window.move({ direction = "left" }))   -- move window left
hl.bind("SUPER + SHIFT + Down",  hl.dsp.window.move({ direction = "down" }))   -- move window down
hl.bind("SUPER + SHIFT + Up",    hl.dsp.window.move({ direction = "up" }))   -- move window up
hl.bind("SUPER + SHIFT + Right", hl.dsp.window.move({ direction = "right" }))   -- move window right

-- Resize by 40 pixels per press; { repeating = true } keeps going while the keys are held.
hl.bind("SUPER + CTRL + Left",  hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true })   -- resize left
hl.bind("SUPER + CTRL + Right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }),  { repeating = true })   -- resize right
hl.bind("SUPER + CTRL + Up",    hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true })   -- resize up
hl.bind("SUPER + CTRL + Down",  hl.dsp.window.resize({ x = 0, y = 40, relative = true }),  { repeating = true })   -- resize down

---- Workspaces 1-10 (the 0 key is workspace 10) ----
-- A loop instead of ten copies: i runs 1..10, and i % 10 turns 10 into the key "0".
for i = 1, 10 do
    local key = tostring(i % 10)
    hl.bind("SUPER + " .. key,           hl.dsp.focus({ workspace = i }))          -- go to workspace i
    hl.bind("SUPER + SHIFT + " .. key,   hl.dsp.window.move({ workspace = i }))    -- send the window there
end

---- Scratchpad (a hidden workspace; see scripts/scratchpad.sh) ----
hl.bind("SUPER + Grave",                    exec(scripts .. "/scratchpad.sh toggle"))   -- scratchpad: show/hide
hl.bind("SUPER + ALT + Up",                 exec(scripts .. "/scratchpad.sh send"))   -- scratchpad: send window
hl.bind("SUPER + ALT + Down",               exec(scripts .. "/scratchpad.sh return"))   -- scratchpad: bring window back
hl.bind("SUPER + CTRL + SHIFT + Up",        exec(scripts .. "/scratchpad.sh send follow"))   -- scratchpad: send window and follow
hl.bind("SUPER + CTRL + SHIFT + Down",      exec(scripts .. "/scratchpad.sh return follow"))   -- scratchpad: bring back and follow

---- Screenshots (saved to ~/Pictures and copied to the clipboard) ----
hl.bind("Print",         exec("sh -c 'file=" .. home .. "/Pictures/$(date +%s).png; grim -g \"$(slurp)\" \"$file\"; wl-copy < \"$file\"; qs ipc call screenshot notify \"$file\"'"))   -- drag an area
hl.bind("SUPER + Print", exec("sh -c 'file=" .. home .. "/Pictures/$(date +%s).png; grim \"$file\"; wl-copy < \"$file\"; qs ipc call screenshot notify \"$file\"'"))              -- whole screen

---- Mouse: Super + left drag moves a window, Super + right drag resizes it ----
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

---- Media, volume, brightness and mic keys ----
-- { locked = true } makes them work on the lock screen too.
hl.bind("XF86AudioRaiseVolume",    exec(scripts .. "/volume.sh up"),   { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",    exec(scripts .. "/volume.sh down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",           exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),   { locked = true })
hl.bind("XF86AudioMicMute",        exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp",     exec(scripts .. "/brightness.sh up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",   exec(scripts .. "/brightness.sh down"), { locked = true, repeating = true })
