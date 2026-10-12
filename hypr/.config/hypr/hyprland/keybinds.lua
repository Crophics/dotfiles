require("hyprland.lib")
require("hyprland.variables")
if is_file_exists(HOME .. "/.config/hypr/custom/variables.lua") then
    require("custom.variables")
end

local qsScripts = "$HOME/.config/quickshell/$qsConfig/scripts"
local hyprScripts = "$HOME/.config/hypr/hyprland/scripts"
local qsIpcCall = "qs -c $qsConfig ipc call"
local qsIsAlive = qsIpcCall .. " TEST_ALIVE"

hl.bind("SUPER + Space", hl.dsp.global("quickshell:searchToggle"), { description = "Shell: Toggle search" })
hl.bind("SUPER + Space", hl.dsp.exec_cmd(qsIsAlive .. " || pkill fuzzel || fuzzel"))

hl.bind("SUPER + V", hl.dsp.global("quickshell:overviewClipboardToggle"))
hl.bind("SUPER + Period", hl.dsp.global("quickshell:overviewEmojiToggle"))
hl.bind("SUPER + Escape", hl.dsp.global("quickshell:sessionToggle"), { description = "Session: Toggle power menu" })
hl.bind("SUPER + N", hl.dsp.global("quickshell:sidebarRightToggle"), { description = "Shell: Toggle right sidebar" })
hl.bind("CTRL + ALT + Delete", hl.dsp.global("quickshell:sessionToggle"), { description = "Shell: Toggle session menu" })
hl.bind("SUPER + J", hl.dsp.global("quickshell:barToggle"), { description = "Shell: Toggle bar" })
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd(qsIsAlive .. " || pkill wlogout || wlogout -p layer-shell"))

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(qsIpcCall .. " brightness increment || brightnessctl s 5%+"),
    { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(qsIpcCall .. " brightness decrement || brightnessctl s 5%-"),
    { locked = true, repeating = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%+ -l 1.5"),
    { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-"),
    { locked = true, repeating = true })

hl.bind("CTRL + SUPER + T", hl.dsp.global("quickshell:wallpaperSelectorToggle"),
    { description = "Shell: Change wallpaper (ii native)" })

--##! Utilities
--# Screenshot, OCR, Color picker, Clipboard history
hl.bind("SUPER + V", hl.dsp.exec_cmd(
        qsIsAlive .. " || pkill fuzzel || cliphist list | fuzzel --match-mode fzf --dmenu | cliphist decode | wl-copy"),
    { description = "Utilities: Clipboard history >> clipboard" })
hl.bind("SUPER + Period", hl.dsp.exec_cmd(
        qsIsAlive .. " || pkill fuzzel || " .. hyprScripts .. "/fuzzel-emoji.sh copy"),
    { description = "Utilities: Emoji >> clipboard" })
--# OCR
hl.bind("SUPER + O", hl.dsp.global("quickshell:regionOcr"),
    { description = "Utilities: Character recognition >> clipboard" })
hl.bind("SUPER + O", hl.dsp.exec_cmd(
        qsIsAlive ..
        " || pidof slurp || grim -g \"$(slurp $SLURP_ARGS)\" \"/tmp/ocr_image.png\" && tesseract \"/tmp/ocr_image.png\" stdout -l $(tesseract --list-langs | awk 'NR>1{print $1}' | tr '\\\\n' '+' | sed 's/\\\\+$/\\\\n/') | wl-copy && rm \"/tmp/ocr_image.png\""))
--# Color picker
hl.bind("SUPER + P", hl.dsp.exec_cmd("hyprpicker -a"),
    { description = "Utilities: Pick color #RRGGBB >> clipboard" })
--# Fullscreen screenshot
local grimhyprctl = "grim -o \"$(hyprctl activeworkspace -j | jq -r '.monitor')\""
hl.bind("Print", hl.dsp.exec_cmd(qsIpcCall .. " region screenshot && notify-send 'Screenshot' 'Region copied to clipboard' -a 'Screenshot'"),
    { locked = true, description = "Utilities: Region screenshot >> clipboard" })
hl.bind("SUPER + Print", hl.dsp.exec_cmd(grimhyprctl .. " - | wl-copy && notify-send 'Screenshot' 'Fullscreen copied to clipboard' -a 'Screenshot'"),
    { locked = true, description = "Utilities: Fullscreen screenshot >> clipboard" })

--##! Screen
--# Zoom
local function zoomfunction(value)
    local zoomvalue = hl.get_config("cursor:zoom_factor")
    if (zoomvalue + value) > 3.0 then
        hl.config({ cursor = { zoom_factor = 3.0 } })
    elseif (zoomvalue + value) < 1.0 then
        hl.config({ cursor = { zoom_factor = 1.0 } })
    else
        hl.config({ cursor = { zoom_factor = zoomvalue + value } })
    end
end
hl.bind("SUPER + Minus", function() zoomfunction(-0.3) end, { repeating = true, description = "Screen: Zoom out" })
hl.bind("SUPER + Equal", function() zoomfunction(0.3) end, { repeating = true, description = "Screen: Zoom in" })

--##! Media
local mediaNextCommand =
"playerctl next || playerctl position `bc <<< \"100 * $(playerctl metadata mpris:length) / 1000000 / 100\"`"
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd(mediaNextCommand), { locked = true, description = "Media: Next track" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd(mediaNextCommand), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("playerctl previous"),
    { locked = true, description = "Media: Previous track" })
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("playerctl play-pause"),
    { locked = true, description = "Media: Play/pause media" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SINK@ toggle"), { locked = true })
hl.bind("ALT + XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_SOURCE@ toggle"), { locked = true })

--#!
--##! Window
--# Focusing
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Window: Move" })
hl.bind("SUPER + mouse:274", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Window: Resize" })
--#/# bind = SUPER + ←/↑/→/↓,, -- Focus in direction
for i = 1, 4 do
    local arrowkey = { "Left", "Right", "Up", "Down" }
    local focusdir = { "l", "r", "u", "d" }
    hl.bind("SUPER + " .. arrowkey[i], hl.dsp.focus({ direction = focusdir[i] }),
        { description = "Window: Focus " .. arrowkey[i] })
end
--#/# bind = SUPER + SHIFT, ←/↑/→/↓,, -- Move in direction
for i = 1, 4 do
    local arrowkey = { "Left", "Right", "Up", "Down" }
    local focusdir = { "l", "r", "u", "d" }
    hl.bind("SUPER + SHIFT + " .. arrowkey[i], hl.dsp.window.move({ direction = focusdir[i] }),
        { description = "Window: Move " .. arrowkey[i] })
end

hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Window: Close" })

--# Window split ratio
--#/# binde = SUPER, ;/',, -- Adjust split ratio
hl.bind("SUPER + Semicolon", hl.dsp.layout("splitratio -0.1"), { repeating = true })
hl.bind("SUPER + Apostrophe", hl.dsp.layout("splitratio +0.1"), { repeating = true })
--# Positioning mode
hl.bind("SUPER + ALT + Space", hl.dsp.window.float({ action = "toggle" }), { description = "Window: Float/Tile" })
hl.bind("SUPER + D", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }),
    { description = "Window: Maximize" })
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }),
    { description = "Window: Fullscreen" })

--#/# bind = SUPER+ALT, Hash,, -- Send to workspace -- (1, 2, 3,...)
for i = 1, 5 do
    hl.bind("SUPER + ALT + " .. (i % 10), function()
        hl.dispatch(hl.dsp.window.move({ workspace = workspace_in_group(i), follow = false }))
    end, { description = "Window: Send to workspace " .. i })
end
--#/# bind = CTRL+SUPER+SHIFT, Hash,, -- Send to workspace and follow -- (1, 2, 3,...)
for i = 1, 5 do
    hl.bind("CTRL + SUPER + SHIFT + " .. (i % 10), function()
        hl.dispatch(hl.dsp.window.move({ workspace = workspace_in_group(i), follow = true }))
    end, { description = "Window: Send to workspace " .. i .. " (follow)" })
end
--#/# bind = SUPER+ALT, up/down,, -- Send to/return from scratchpad, stay put
--#/# bind = CTRL+SUPER+SHIFT, up/down,, -- Send to/return from scratchpad, follow
local function sendToScratchpad(follow)
    hl.dispatch(hl.dsp.window.move({ workspace = "special:special", follow = follow }))
end
local function returnFromScratchpad(follow)
    local current = hl.get_active_workspace().id
    hl.dispatch(hl.dsp.window.move({ workspace = tostring(current), follow = follow }))
end

hl.bind("SUPER + ALT + Up", function() sendToScratchpad(false) end, { description = "Window: Send to scratchpad" })
hl.bind("SUPER + ALT + Down", function() returnFromScratchpad(false) end, { description = "Window: Return from scratchpad" })
hl.bind("CTRL + SUPER + SHIFT + Up", function() sendToScratchpad(true) end,
    { description = "Window: Send to scratchpad (follow)" })
hl.bind("CTRL + SUPER + SHIFT + Down", function() returnFromScratchpad(true) end,
    { description = "Window: Return from scratchpad (follow)" })

--#/# bind = CTRL+SUPER, up/down,, -- Enter/exit scratchpad, focus only
hl.bind("CTRL + SUPER + Up", hl.dsp.exec_cmd(hyprScripts .. "/scratchpad-focus.sh up"),
    { description = "Workspace: Enter scratchpad" })
hl.bind("CTRL + SUPER + Down", hl.dsp.exec_cmd(hyprScripts .. "/scratchpad-focus.sh down"),
    { description = "Workspace: Exit scratchpad" })

--#/# bind = CTRL+SUPER+SHIFT, ←/→,, -- Send to workspace left/right, follow
--#/# bind = SUPER+ALT, ←/→,, -- Send to workspace left/right, stay put
local function moveWindowToAdjacentWorkspace(dir, follow)
    local current = hl.get_active_workspace().id
    local target = current + dir
    if target > 5 then target = 1 end
    if target < 1 then target = 5 end
    hl.dispatch(hl.dsp.window.move({ workspace = tostring(target), follow = follow }))
    if not follow then
        -- Moving the last window off the current workspace makes Hyprland
        -- auto-switch focus elsewhere on its own; force staying put instead.
        hl.dispatch(hl.dsp.focus({ workspace = tostring(current) }))
    end
end

hl.bind("CTRL + SUPER + SHIFT + Left", function() moveWindowToAdjacentWorkspace(-1, true) end,
    { description = "Window: Send to workspace left (follow)" })
hl.bind("CTRL + SUPER + SHIFT + Right", function() moveWindowToAdjacentWorkspace(1, true) end,
    { description = "Window: Send to workspace right (follow)" })
hl.bind("SUPER + ALT + Left", function() moveWindowToAdjacentWorkspace(-1, false) end,
    { description = "Window: Send to workspace left" })
hl.bind("SUPER + ALT + Right", function() moveWindowToAdjacentWorkspace(1, false) end,
    { description = "Window: Send to workspace right" })

--##! Workspace
--# Switching
--#/# bind = SUPER, Hash,, -- Focus workspace -- (1, 2, 3,...)
for i = 1, 5 do
    hl.bind("SUPER + " .. (i % 10), function()
        hl.dispatch(hl.dsp.focus({ workspace = workspace_in_group(i) }))
    end, { description = "Workspace: Focus " .. i })
end
--#/# bind = CTRL+SUPER, ←/→,, -- Focus left/right
local function scrollToWorkspace(dir)
    local current = hl.get_active_workspace().id
    local target = current + dir
    if target > 5 then target = 1 end
    if target < 1 then target = 5 end
    hl.dispatch(hl.dsp.focus({ workspace = tostring(target) }))
end

hl.bind("CTRL + SUPER + Left",  function() scrollToWorkspace(-1) end, {description = "Workspace: Focus left"})
hl.bind("CTRL + SUPER + Right", function() scrollToWorkspace(1) end, {description = "Workspace: Focus right"})

--##! Session
hl.bind("SUPER + L", hl.dsp.exec_cmd("loginctl lock-session"), { description = "Session: Lock" })
hl.bind("SUPER + SHIFT + L", hl.dsp.exec_cmd("systemctl suspend || loginctl suspend"),
    { locked = true, description = "Session: Sleep" }) -- Sleep
-- hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("systemctl suspend || loginctl suspend"), {locked = true} ) -- # [hidden] Suspend when laptop lid is closed, uncomment if for whatever reason it's not the default behavior

--##! Apps
hl.bind("SUPER + Return", hl.dsp.exec_cmd(terminal), { description = "App: Terminal" })
hl.bind("SUPER + E", hl.dsp.exec_cmd(fileManager), { description = "App: File manager" })
hl.bind("SUPER + W", hl.dsp.exec_cmd(browser), { description = "App: Browser" })
hl.bind("SUPER + C", hl.dsp.exec_cmd(codeEditor), { description = "App: Code editor" })
hl.bind("SUPER + X", hl.dsp.exec_cmd(textEditor), { description = "App: Text editor" })
hl.bind("SUPER + S", hl.dsp.exec_cmd("spotify"), { description = "App: Spotify" })
hl.bind("SUPER + B", hl.dsp.exec_cmd("bitwarden-desktop"), { description = "App: Bitwarden" })
hl.bind("SUPER + K", hl.dsp.exec_cmd("gnome-calculator"), { description = "App: Calculator" })
hl.bind("CTRL + SUPER + V", hl.dsp.exec_cmd(volumeMixer), { description = "App: Volume mixer" })
hl.bind("SUPER + I", hl.dsp.global("quickshell:settingsToggle"), { description = "Shell: Toggle settings panel" })
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd(taskManager), { description = "App: Task manager" })
