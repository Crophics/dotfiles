hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
-- No NVIDIA vars here (unlike upstream): this laptop's display runs on the Intel iGPU,
-- and GBM_BACKEND/__GLX_VENDOR_LIBRARY_NAME=nvidia would break that.

-- Wayland-native Electron/Qt apps, and flatpak apps in the launcher
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
local home = os.getenv("HOME")
hl.env(
	"XDG_DATA_DIRS",
	home .. "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:" .. (os.getenv("XDG_DATA_DIRS") or "/usr/local/share:/usr/share")
)
