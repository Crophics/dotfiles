-- Behaviour settings carried over from the old (illogical-impulse) config.
-- Looks live in look.lua; this is everything that isn't about looks.
hl.config({
	misc = {
		mouse_move_enables_dpms = true,
		key_press_enables_dpms = true,
		animate_manual_resizes = false,
		animate_mouse_windowdragging = false,
		on_focus_under_fullscreen = 2,
		allow_session_lock_restore = true, -- recover if qylock crashes instead of a red screen
		session_lock_xray = true,
		initial_workspace_tracking = false,
		focus_on_activate = true,
		vrr = 0,
	},

	binds = {
		scroll_event_delay = 0,
		hide_special_on_workspace_change = true,
	},

	cursor = {
		zoom_rigid = false,
		zoom_disable_aa = true,
		hotspot_padding = 1,
	},

	-- XWayland apps (Spotify, Steam, ...) render at 1x instead of being upscaled
	-- (blurry) to the 1.2 monitor scale
	xwayland = {
		force_zero_scaling = true,
	},
})
