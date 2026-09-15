-- Palette: the tinty-rendered file when present (theme set ...), else the
-- Catppuccin Mocha fallback below so the bar works before the first apply.
local data_home = os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share")
local generated = data_home .. "/tinted-theming/tinty/artifacts/sketchybar-build-file.lua"

local ok, palette = pcall(dofile, generated)
if not ok or type(palette) ~= "table" then
	palette = {
		black = 0xff1e1e2e,
		white = 0xffcdd6f4,
		red = 0xfff38ba8,
		orange = 0xfffab387,
		yellow = 0xfff9e2af,
		green = 0xffa6e3a1,
		cyan = 0xff94e2d5,
		blue = 0xff89b4fa,
		magenta = 0xffcba6f7,
		brown = 0xfff2cdcd,
		grey = 0xff45475a,
		peach = 0xfffab387,
		arise = 0xfff5e0dc,
		transparent = 0x00000000,
		bg1 = 0xff181825,
		bg2 = 0xff313244,
		bar = { bg = 0xf01e1e2e, border = 0xff181825, blur_radius = 80 },
		popup = { bg = 0x991e1e2e, border = 0xff313244, blur_radius = 60 },
	}
end

palette.with_alpha = function(color, alpha)
	if alpha > 1.0 or alpha < 0.0 then
		return color
	end
	return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
end

return palette
