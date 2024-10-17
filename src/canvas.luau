--!optimize 2
--!native
--!strict

export type RGBACanvas = buffer

export type RGBA = number

export type Canvas = {
	canvas: RGBACanvas,
	length: number,
	width: number,
	height: number,
	cellSize: number,
}

local Canvas = {}

Canvas.drawBitmap = function(canvas: Canvas, x: number, y: number, buf: buffer, fgColor: RGBA, bgColor: RGBA?): ()
	if buffer.len(fgColor) ~= 4 or (bgColor and buffer.len(bgColor) ~= 4) then
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
	-- Only checks if the overdraw happens past the size of the canvas table to prevent out of bounds errors
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

				buffer.writeu32(canvasBuffer, pos, fgColor * bit + bgColor * (1 - bit))
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

				local bg = buffer.readu32(canvasBuffer, pos)

				buffer.writeu32(canvasBuffer, pos, fgColor * bit + bg * (1 - bit))
			end
		end
	end
end

Canvas.fillCell = function(canvas: Canvas, x: number, y: number, color: RGBA): ()
	local buf = canvas.canvas
	local pixelOffsetX = x * canvas.cellSize
	local pixelOffsetY = y * canvas.cellSize * 2
	local canvasWidth = canvas.width * canvas.cellSize

	for y0 = 0, canvas.cellSize * 2 - 1 do
		for x0 = 0, canvas.cellSize - 1 do
			local x1 = pixelOffsetX + x0
			local y1 = pixelOffsetY + y0
			local i = (x1 + y1 * canvasWidth) * 4
			buffer.writeu32(buf, i, color)
		end
	end
end

Canvas.fillLine = function(canvas: Canvas, y: number, color: RGBA): ()
	local buf = canvas.canvas
	local lineOffset = canvas.length / canvas.height
	local startIndex = lineOffset * y
	local endIndex = startIndex + lineOffset - 1
	for i = startIndex, endIndex, 4 do
		buffer.writeu32(buf, i, color)
	end
end

Canvas.fillScreen = function(canvas: Canvas, color: RGBA): ()
	local buf = canvas.canvas
	for i = 0, canvas.length - 1, 4 do
		buffer.writeu32(buf, i, color)
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

Canvas.shiftDown = function(canvas: Canvas, lines: number, color: RGBA): ()
	local clampedLines = math.clamp(lines, 1, canvas.height)
	local lineHeight = canvas.length / canvas.height
	local lineOffset = clampedLines * lineHeight

	local buf = canvas.canvas
	buffer.copy(buf, lineOffset, buf, 0, canvas.length - lineOffset)

	for y = 0, clampedLines - 1 do
		Canvas.fillLine(canvas, y, color)
	end
end

Canvas.shiftUp = function(canvas: Canvas, lines: number, color: RGBA): ()
	local clampedLines = math.clamp(lines, 1, canvas.height)
	local lineHeight = canvas.length / canvas.height
	local lineOffset = clampedLines * lineHeight

	local buf = canvas.canvas
	buffer.copy(buf, 0, buf, lineOffset, canvas.length - lineOffset)

	for y = 1, clampedLines do
		Canvas.fillLine(canvas, canvas.height - y, color)
	end
end

Canvas.createCanvas = function(w: number, h: number, cellSize: number?): Canvas
	local cs = cellSize or 8
	local len = w * h * cs * cs * 2 * 4
	local canvas: Canvas = {
		canvas = buffer.create(len),
		length = len,
		width = w,
		height = h,
		cellSize = cs,
	}
	Canvas.fillScreen(canvas, 0x000000ff)
	return canvas
end

return Canvas
