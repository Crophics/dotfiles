-- This file will not be overwritten across dots-hyprland updates.
-- The file name is for the sake of organization and does not matter
-- See the corresponding files in ~/.config/hypr/hyprland for examples

-- Default to the Playback (per-application) tab instead of Output Devices
volumeMixer = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'pavucontrol-qt --tab 1' 'pavucontrol'"

-- Desktop shell: "noctalia" or "ii" (end-4 quickshell).
-- Falls back to ii automatically if Noctalia isn't installed, so this is safe to leave set.
desktopShell = "noctalia"
if desktopShell == "noctalia" and not is_file_exists("/usr/bin/noctalia") then
	desktopShell = "ii"
end

-- Animated wallpaper (mpvpaper, Noctalia mode only). Point this symlink at any video:
--   ln -sf ~/Videos/Wallpapers/whatever.mp4 ~/Videos/Wallpapers/current
wallpaperVideo = HOME .. "/Videos/Wallpapers/current"
