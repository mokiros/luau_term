--!optimize 2
--!native
--!strict

export type RGBACanvas = { number }

export type RGBA = { number }

export type Canvas = {
	canvas: RGBACanvas,
	width: number,
	height: number,
	cellSize: number,
}

local Canvas = {}

Canvas.drawBitmap = function(canvas: Canvas, x: number, y: number, buf: buffer, fgColor: RGBA, bgColor: RGBA?): ()
	if #fgColor ~= 4 or (bgColor and #bgColor ~= 4) then
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

	if bgColor then
		for byteIndex = 0, len - 1, 4 do
			local num = buffer.readu32(buf, byteIndex)
			for bitIndex = 0, 31 do
				local bit = bit32.extract(num, 31 - bitIndex, 1)
				local idx = byteIndex * 8 + bitIndex
				local x1 = pixelOffsetX + idx % pixelWidth
				local y1 = pixelOffsetY + (idx // pixelWidth)
				local pos = (x1 + y1 * canvasWidth) * 4

				canvasBuffer[pos + 1] = fgColor[1] * bit + bgColor[1] * (1 - bit)
				canvasBuffer[pos + 2] = fgColor[2] * bit + bgColor[2] * (1 - bit)
				canvasBuffer[pos + 3] = fgColor[3] * bit + bgColor[3] * (1 - bit)
				canvasBuffer[pos + 4] = fgColor[4] * bit + bgColor[4] * (1 - bit)
			end
		end
	else
		for byteIndex = 0, len - 1, 4 do
			local num = buffer.readu32(buf, byteIndex)
			for bitIndex = 0, 31 do
				local bit = bit32.extract(num, 31 - bitIndex, 1)
				local idx = byteIndex * 8 + bitIndex
				local x1 = pixelOffsetX + idx % pixelWidth
				local y1 = pixelOffsetY + (idx // pixelWidth)
				local pos = (x1 + y1 * canvasWidth) * 4

				if bit ~= 1 then
					continue
				end

				canvasBuffer[pos + 1] = fgColor[1]
				canvasBuffer[pos + 2] = fgColor[2]
				canvasBuffer[pos + 3] = fgColor[3]
				canvasBuffer[pos + 4] = fgColor[4]
			end
		end
	end
end

Canvas.fillCell = function(canvas: Canvas, x: number, y: number, color: RGBA): ()
	local t = canvas.canvas
	local pixelOffsetX = x * canvas.cellSize
	local pixelOffsetY = y * canvas.cellSize * 2
	local canvasWidth = canvas.width * canvas.cellSize

	for y0 = 0, canvas.cellSize * 2 - 1 do
		for x0 = 0, canvas.cellSize - 1 do
			local x1 = pixelOffsetX + x0
			local y1 = pixelOffsetY + y0
			local i = (x1 + y1 * canvasWidth) * 4 + 1

			t[i] = color[1]
			t[i + 1] = color[2]
			t[i + 2] = color[3]
			t[i + 3] = color[4]
		end
	end
end

Canvas.fillLine = function(canvas: Canvas, y: number, color: RGBA): ()
	local t = canvas.canvas
	local lineOffset = canvas.width * canvas.cellSize * canvas.cellSize * 2 * 4
	local startIndex = lineOffset * y
	local endIndex = lineOffset * (y + 1) - 1
	for i = startIndex, endIndex, 4 do
		t[i] = color[1]
		t[i + 1] = color[2]
		t[i + 2] = color[3]
		t[i + 3] = color[4]
	end
end

Canvas.fillScreen = function(canvas: Canvas, color: RGBA): ()
	local t = canvas.canvas
	local size = canvas.width * canvas.height * canvas.cellSize * canvas.cellSize * 2 * 4
	for i = 1, size, 4 do
		t[i] = color[1]
		t[i + 1] = color[2]
		t[i + 2] = color[3]
		t[i + 3] = color[4]
	end
end

Canvas.fillBetween = function(canvas: Canvas, x1: number, y1: number, x2: number, y2: number, color: RGBA): ()
	local w = canvas.width
	local pos1 = x1 + y1 * w
	local pos2 = x2 + y2 * w
	if pos1 > pos2 then
		pos1, pos2 = pos2, pos1
	end
	for pos = pos1, pos2 do
		local x, y = pos % w, pos // w
		Canvas.fillCell(canvas, x, y, color)
	end
end

Canvas.shiftUp = function(canvas: Canvas, lines: number, color: RGBA): ()
	local w = canvas.width * canvas.cellSize
	local l = math.clamp(lines, 1, canvas.height)
	local h = l * canvas.cellSize * 2
	local startIndex = w * h * 4 + 1
	local endIndex = w * canvas.height * canvas.cellSize * 2 * 4
	table.move(canvas.canvas, startIndex, endIndex, 1)
	for y = canvas.height - l, canvas.height - 1 do
		Canvas.fillLine(canvas, y, color)
	end
end

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
