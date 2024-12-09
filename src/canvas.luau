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

Canvas.fillLines = function(canvas: Canvas, startY: number, lineCount: number, color: RGBA): ()
	local buf = canvas.canvas
	local lineLength = canvas.length / canvas.height
	local startOffset = startY * lineLength
	local totalPixelLength = lineLength / 4 * lineCount

	-- Instead of writing to each pixel individually, the code below
	-- copies previously written chunks, so on every iteration it copies
	-- twice as much
	local n = math.log(totalPixelLength, 2)
	buffer.writeu32(buf, startOffset, color)
	local count = 1
	for i = 1, n do
		buffer.copy(buf, startOffset + count * 4, buf, startOffset, count * 4)
		count *= 2
	end

	local remaining = totalPixelLength - count
	if remaining > 0 then
		buffer.copy(buf, startOffset + count * 4, buf, startOffset, remaining * 4)
	end
end

Canvas.fillScreen = function(canvas: Canvas, color: RGBA): ()
	Canvas.fillLines(canvas, 0, canvas.height, color)
end

--- Moves the canvas **DOWN**, adding lines on the top
Canvas.shiftDown = function(canvas: Canvas, lines: number, topMargin: number, bottomMargin: number, color: RGBA): ()
	local availableLines = canvas.height - topMargin - bottomMargin

	if availableLines < 1 then
		warn("Margins exceed canvas height, not shifting")
		return
	end

	local clampedLines = math.clamp(lines, 1, availableLines)
	local lineHeight = canvas.length / canvas.height
	local startOffset = topMargin * lineHeight
	local lineOffset = startOffset + clampedLines * lineHeight
	local endOffset = (canvas.height - bottomMargin) * lineHeight

	local buf = canvas.canvas
	buffer.copy(buf, lineOffset, buf, startOffset, endOffset - lineOffset)

	Canvas.fillLines(canvas, topMargin, clampedLines, color)
end

--- Moves the canvas **UP**, adding lines on the bottom
Canvas.shiftUp = function(canvas: Canvas, lines: number, topMargin: number, bottomMargin: number, color: RGBA): ()
	local availableLines = canvas.height - topMargin - bottomMargin
	
	if availableLines < 1 then
		warn("Margins exceed canvas height, not shifting")
		return
	end
	
	local clampedLines = math.clamp(lines, 1, availableLines)
	local lineHeight = canvas.length / canvas.height
	local startOffset = topMargin * lineHeight
	local lineOffset = startOffset + clampedLines * lineHeight
	local endOffset = (canvas.height - bottomMargin) * lineHeight

	local buf = canvas.canvas
	buffer.copy(buf, startOffset, buf, lineOffset, endOffset - lineOffset)

	Canvas.fillLines(canvas, canvas.height - bottomMargin - clampedLines, clampedLines, color)
end

Canvas.shiftRight = function(canvas: Canvas, y: number, startX: number, endX: number, emptyCellCount: number, bgColor: RGBA): ()
	local width = endX - startX
	local cellsToCopy = width - emptyCellCount

	if cellsToCopy > 0 then
		local cellHeight = canvas.cellSize * 2
		local lineWidth = canvas.length / canvas.height
		local lineOffset = lineWidth / cellHeight
		local startOffset = lineWidth * y + startX * canvas.cellSize * 4
		local buf = canvas.canvas
		for line = 0, cellHeight do
			buffer.copy(
				buf,
				startOffset + lineOffset * line + emptyCellCount * canvas.cellSize * 4,
				buf,
				startOffset + lineOffset * line,
				cellsToCopy * canvas.cellSize * 4
			)
		end
	end

	for x = 0, emptyCellCount do
		Canvas.fillCell(canvas, startX + x, y, bgColor)
	end
end

Canvas.shiftLeft = function(canvas: Canvas, y: number, startX: number, endX: number, emptyCellCount: number, bgColor: RGBA): ()
	local width = endX - startX
	local cellsToCopy = width - emptyCellCount

	if cellsToCopy > 0 then
		local cellHeight = canvas.cellSize * 2
		local lineWidth = canvas.length / canvas.height
		local lineOffset = lineWidth / cellHeight
		local startOffset = lineWidth * y + startX * canvas.cellSize * 4
		local buf = canvas.canvas
		for line = 0, cellHeight do
			buffer.copy(
				buf,
				startOffset + lineOffset * line,
				buf,
				startOffset + lineOffset * line + emptyCellCount * canvas.cellSize * 4,
				cellsToCopy * canvas.cellSize * 4
			)
		end
	end

	for x = 0, emptyCellCount do
		Canvas.fillCell(canvas, endX - x, y, bgColor)
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

return table.freeze(Canvas)
