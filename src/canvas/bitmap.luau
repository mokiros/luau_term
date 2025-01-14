--!optimize 2
--!native
--!strict

local Types = require("./types")

type BitmapCanvas = buffer

local BitmapCanvas = {} :: Types.CanvasModule<BitmapCanvas, buffer>

local underlineGlyph = buffer.create(16)
buffer.writeu8(underlineGlyph, 12, 0xFF)

BitmapCanvas.draw = function(canvas, x, y, buf, att, fgColor, bgColor)
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

	if att.underline then
		BitmapCanvas.draw(canvas, x, y, underlineGlyph, {} :: any, fgColor)
	end
end

BitmapCanvas.fillCell = function(canvas, x, y, color)
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

BitmapCanvas.fillLines = function(canvas, startY, lineCount, color)
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

BitmapCanvas.fillScreen = function(canvas, color)
	BitmapCanvas.fillLines(canvas, 0, canvas.height, color)
end

--- Moves the canvas **DOWN**, adding lines on the top
BitmapCanvas.shiftDown = function(canvas, lines, topMargin, bottomMargin, color)
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

	BitmapCanvas.fillLines(canvas, topMargin, clampedLines, color)
end

--- Moves the canvas **UP**, adding lines on the bottom
BitmapCanvas.shiftUp = function(canvas, lines, topMargin, bottomMargin, color)
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

	BitmapCanvas.fillLines(canvas, canvas.height - bottomMargin - clampedLines, clampedLines, color)
end

BitmapCanvas.shiftRight = function(canvas, y, startX, endX, emptyCellCount, bgColor)
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

	for x = 0, emptyCellCount - 1 do
		BitmapCanvas.fillCell(canvas, startX + x, y, bgColor)
	end
end

BitmapCanvas.shiftLeft = function(canvas, y, startX, endX, emptyCellCount, bgColor)
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

	for x = 0, emptyCellCount - 1 do
		BitmapCanvas.fillCell(canvas, endX - x, y, bgColor)
	end
end

BitmapCanvas.createCanvas = function(w, h, cellSize)
	local cs = cellSize or 8
	local len = w * h * cs * cs * 2 * 4
	local canvas: Types.Canvas<BitmapCanvas> = {
		canvas = buffer.create(len),
		length = len,
		width = w,
		height = h,
		cellSize = cs,
	}

	return canvas
end

return table.freeze(BitmapCanvas)
