--monitors organized from left to right
--just change this to setup your monitors
MONITORS = {
	{
		output = "eDP-1",
		mode = "1920x1200@60",
		position = "0x0",
		scale = 1.2,
	},
}

for _, value in ipairs(MONITORS) do
	hl.monitor({
		output = value.output,
		mode = value.mode,
		position = value.position,
		scale = value.scale,
	})
end

-- anything else that gets plugged in (HDMI, docks): sensible defaults, to the right
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
