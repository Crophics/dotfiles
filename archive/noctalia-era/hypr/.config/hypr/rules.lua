--windows
hl.window_rule({
	-- Ignore maximize requests from all apps. You'll probably like this.
	name = "suppress-maximize-events",
	match = { class = ".*" },

	suppress_event = "maximize",
})

hl.window_rule({
	-- Fix some dragging issues with XWayland
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},

	no_focus = true,
})

--fullscreen proton apps by default
hl.window_rule({
	match = {
		class = [[^(steam_app_\d+|steam_app_default)$]],
	},
	fullscreen = true,
})

hl.window_rule({
	match = {
		title = "Battle.net",
	},
	fullscreen = false,
})

--workspaces

hl.workspace_rule({
	workspace = "1",
	monitor = MONITORS[1].output,
	default = true,
	persistent = true,
	default_name = "chat",
})

hl.workspace_rule({
	workspace = "5",
	monitor = MONITORS[1].output,
	persistent = true,
	default_name = "code",
})

hl.workspace_rule({ workspace = "2", monitor = MONITORS[1].output, persistent = true, default_name = "web" })
hl.workspace_rule({ workspace = "3", monitor = MONITORS[1].output, persistent = true, default_name = "misc" })
hl.workspace_rule({ workspace = "4", monitor = MONITORS[1].output, persistent = true, default_name = "notes" })

--local additions (not in upstream)

--Steam games on their own workspace
hl.window_rule({ match = { class = "^(steam_app.*|gamescope)$" }, workspace = "name:gaming" })
hl.window_rule({ match = { class = "^(steam)$", title = "^(Friends List)$" }, float = true })

--floating dialogs/utilities
local floating = {
	{ title = "^(Open File|Select a File|Open Folder|Save As|File Upload|Library)(.*)$" },
	{ title = "^(.*)(wants to (save|open))$" },
	{ class = "^(org.pulseaudio.pavucontrol|pavucontrol|nm-connection-editor|blueberry\\.py)$" },
	{ class = "^(kvantummanager|qt[56]ct|nwg-look)$" },
	{ class = "^(org.gnome.Calculator)$" },
}
for _, m in ipairs(floating) do
	hl.window_rule({ match = m, float = true, center = true })
end

--picture-in-picture: small, pinned, bottom right
hl.window_rule({
	match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
	float = true,
	pin = true,
	keep_aspect_ratio = true,
	size = { "(monitor_w*0.25)", "(monitor_h*0.25)" },
	move = { "(monitor_w*0.73)", "(monitor_h*0.72)" },
})

--noctalia: blur its layers, float its settings window
hl.layer_rule({
	name = "noctalia",
	match = { namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$" },
	no_anim = true,
	ignore_alpha = 0.5,
	blur = true,
	blur_popups = true,
})
hl.window_rule({ match = { class = "dev.noctalia.Noctalia" }, float = true, size = { 1080, 920 } })
