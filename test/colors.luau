local DefaultTheme = table.freeze({
	Color3.fromRGB(0, 0, 0),
	Color3.fromRGB(187, 0, 0),
	Color3.fromRGB(0, 187, 0),
	Color3.fromRGB(187, 187, 0),
	Color3.fromRGB(0, 0, 187),
	Color3.fromRGB(187, 0, 187),
	Color3.fromRGB(0, 187, 187),
	Color3.fromRGB(187, 187, 187),

	-- bright colors
	Color3.fromRGB(85, 85, 85),
	Color3.fromRGB(255, 85, 85),
	Color3.fromRGB(85, 255, 85),
	Color3.fromRGB(255, 255, 85),
	Color3.fromRGB(85, 85, 255),
	Color3.fromRGB(255, 85, 255),
	Color3.fromRGB(85, 255, 255),
	Color3.fromRGB(255, 255, 255),
})

local function ColorsToRGBA(colors: { Color3 }): { { number } }
	local t = table.create(16)
	for i = 1, 16 do
		local clr = colors[i]
		t[i] = { clr.R, clr.G, clr.B, 1 }
	end
	return t
end

return {
	Default = ColorsToRGBA(DefaultTheme),
}
