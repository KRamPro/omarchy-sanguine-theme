-- Sanguine theme Hyprland overrides.
-- Blood-red border, deep crimson glow.

-- Alpha channel on the color controls transparency: ff = opaque,
-- cc ≈ 80%, 99 ≈ 60%, 66 ≈ 40%
local active_border_color = "rgba(8c2f2fb8)" -- blood red at ~72% opacity
local active_shadow_color = "rgb(38090e)"    -- very deep crimson
local inactive_border_color = "rgba(00000000)"
local inactive_shadow_color = "rgba(1a0d0e55)"

hl.config({
	general = {
		border_size = 1,

		col = {
			active_border = active_border_color,
			inactive_border = inactive_border_color,
		},
	},

	group = {
		col = {
			border_active = active_border_color,
			border_inactive = inactive_border_color,
		},
	},

	decoration = {
		shadow = {
			enabled = true,
			range = 10,
			render_power = 3,
			color = active_shadow_color,
			color_inactive = inactive_shadow_color,
		},
	},
})
