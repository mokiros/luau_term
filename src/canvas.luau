export type RGBACanvas = { number }

export type RGBA = { number }

export type Canvas = {
	canvas: RGBACanvas,
	width: number,
	height: number,
	cellSize: number,
}

local Canvas = {}

Canvas.drawBitmap = function(canvas: Canvas, x: number, y: number, buf: buffer, fgColor: RGBA, bgColor: RGBA): ()
	if #fgColor ~= 4 or #bgColor ~= 4 then
		error("Invalid colors: length must be 4")
	end

	local len = buffer.len(buf)
	local cellHeight = canvas.cellSize * 2
	if (len * 8) % cellHeight ~= 0 then
		error(`Unsupported glyph size: {len}`)
	end

	local pixelWidth = (len * 8) // cellHeight
	local pixelOffsetX = x * canvas.cellSize
	local pixelOffsetY = y * cellHeight
	local canvasWidth = canvas.width * canvas.cellSize

	-- Overdraw check
	-- Only checks if the overdraw happens past the size of the canvas table to prevent length from changing
	if pixelOffsetX + pixelWidth > canvasWidth and pixelOffsetY + cellHeight >= canvas.height * canvas.cellSize then
		-- TODO: Handle overdraw without an error, but also without branching in the loops below
		error(`Overdraw detected, buffer length: {len}, cell size: {canvas.cellSize}, x: {x}, y: {y}`)
	end

	local canvasBuffer = canvas.canvas

	for byteIndex = 0, len - 1, 4 do
		local num = buffer.readu32(buf, byteIndex)
		for bitIndex = 0, 31 do
			local bit = bit32.extract(num, 31 - bitIndex, 1)
			local idx = byteIndex * 8 + bitIndex
			local x1 = pixelOffsetX + idx % pixelWidth
			local y1 = pixelOffsetY + (idx // pixelWidth)
			local pos = (x1 + y1 * canvasWidth) * 4

			-- TODO: Check what's more performant: using `if` to pick color or use both colors with math
			-- Also figure out if it's better to use `for i = 1,4 do` loop or these 4 statements
			canvasBuffer[pos + 1] = fgColor[1] * bit + bgColor[1] * (1 - bit)
			canvasBuffer[pos + 2] = fgColor[2] * bit + bgColor[2] * (1 - bit)
			canvasBuffer[pos + 3] = fgColor[3] * bit + bgColor[3] * (1 - bit)
			canvasBuffer[pos + 4] = fgColor[4] * bit + bgColor[4] * (1 - bit)
		end
	end
end

Canvas.fillCell = function(canvas: Canvas, x: number, y: number, color: RGBA): ()
	local pixelOffsetX = x * canvas.cellSize
	local pixelOffsetY = y * canvas.cellSize * 2
	local canvasWidth = canvas.width * canvas.cellSize

	for y0 = 0, canvas.cellSize * 2 - 1 do
		for x0 = 0, canvas.cellSize - 1 do
			local x1 = pixelOffsetX + x0
			local y1 = pixelOffsetY + y0
			local pos = (x1 + y1 * canvasWidth) * 4

			table.move(color, 1, 4, pos + 1, canvas.canvas)
		end
	end
end

Canvas.fillLine = function(canvas: Canvas, y: number, color: RGBA): ()
	for x = 0, canvas.width - 1 do
		Canvas.fillCell(canvas, x, y, color)
	end
end

Canvas.fillScreen = function(canvas: Canvas, color: RGBA): ()
	for y = 0, canvas.height - 1 do
		Canvas.fillLine(canvas, y, color)
	end
end

Canvas.shiftUp = function(canvas: Canvas, lines: number?): () end

Canvas.createCanvas = function(w: number, h: number, cellSize: number?): Canvas
	local cs = cellSize or 8
	local pixelWidth = w * cs
	local pixelHeight = h * cs * 2
	local canvas: Canvas = {
		canvas = table.create(pixelWidth * pixelHeight * 4, 1),
		width = w,
		height = h,
		cellSize = cs,
	}
	Canvas.fillScreen(canvas, { 0, 0, 0, 1 })
	return canvas
end

return Canvas
