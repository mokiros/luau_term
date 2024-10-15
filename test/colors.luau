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

local function ColorsToRGBA(colors: { Color3 }): { buffer }
	local t = table.create(16)
	for i = 1, 16 do
		local clr = colors[i]
		local buf = buffer.create(4)
		buffer.writeu8(buf, 0, math.round(clr.R * 255))
		buffer.writeu8(buf, 1, math.round(clr.G * 255))
		buffer.writeu8(buf, 2, math.round(clr.B * 255))
		buffer.writeu8(buf, 3, 255)
		t[i] = buf
	end
	return t
end

return {
	Default = ColorsToRGBA(DefaultTheme),
}
