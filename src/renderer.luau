local Colors = require(script.Parent.ansi.colors)

type characterUnit = number
type pixelUnit = number

export type TerminalCanvas = {
	width: characterUnit,
	canvasWidth: pixelUnit,
	height: characterUnit,
	canvasHeight: pixelUnit,
	buffer: { number },
	font: { [number]: buffer },
	bgColor: Color3,
	fgColor: Color3,
	attributes: { [string]: any },
}

local defaultFGindex = 8
local defaultBGindex = 1

local parseUnifont = require(script.Parent.unifont)
local DefaultUnifont = parseUnifont(require(script.Parent["unifont.hex"]))

local function drawCodepoint(canvas: TerminalCanvas, codepoint: number, x: characterUnit, y: characterUnit): ()
	local glyphData = canvas.font[codepoint] or canvas.font[0xFFFD] or error(`Unknown codepoint: {codepoint}`)
	local len = buffer.len(glyphData)

	-- Only support 8x16 or 16x16 characters
	local width = if len == 32 then 16 else if len == 16 then 8 else error(`Unsupported glyph width: {len}`)

	local bg, fg = canvas.bgColor, canvas.fgColor
	local canvasBuffer = canvas.buffer
	local canvasWidth = canvas.canvasWidth

	-- x and y is character position, need to convert to pixel position
	local x0, y0 = x * 8, y * 16

	-- Iterating through every 32-bit unsigned integer
	for byteIndex = 0, len - 1, 4 do
		local num = buffer.readu32(glyphData, byteIndex)

		for bitIndex = 0, 31 do
			local clr = if bit32.extract(num, 31 - bitIndex, 1) ~= 0 then fg else bg
			local idx = byteIndex * 8 + bitIndex
			local x1: pixelUnit = x0 + idx % width
			local y1: pixelUnit = y0 + (idx // width)
			if x1 >= canvasWidth then -- Prevent overdraw
				continue
			end
			local pos = (x1 + y1 * canvasWidth) * 4

			canvasBuffer[pos + 1] = clr.R
			canvasBuffer[pos + 2] = clr.G
			canvasBuffer[pos + 3] = clr.B
		end
	end
end

-- clears entire horizontal lines
-- lineCount defaults to 1
local function clearLines(canvas: TerminalCanvas, y: number, lineCount: number?): ()
	local lineWidth = canvas.canvasWidth * 4
	local startPos = y * 16 * lineWidth
	local endPos = math.clamp(y + (lineCount or 1), 0, canvas.height) * 16 * lineWidth - 1
	local bg = canvas.bgColor
	local canvasBuffer = canvas.buffer
	for i = startPos, endPos, 4 do
		canvasBuffer[i + 1] = bg.R
		canvasBuffer[i + 2] = bg.B
		canvasBuffer[i + 3] = bg.G
	end
end

local function clearCanvas(canvas: TerminalCanvas): ()
	clearLines(canvas, 0, canvas.height)
end

local function clearBox(canvas: TerminalCanvas, x0: number, y0: number, w: number, h: number): ()
	local x1 = math.clamp(x0, 0, canvas.width - 1)
	local y1 = math.clamp(y0, 0, canvas.height - 1)

	local x2 = math.clamp(x1 + w - 1, 0, canvas.width - 1)
	local y2 = math.clamp(y1 + h - 1, 0, canvas.height - 1)

	local bg = canvas.bgColor
	local canvasBuffer = canvas.buffer

	-- ????
	for y = y1 * 16, y2 * 16 + 15 do
		for x = (x1 * 8) * 4, (x2 * 8 + 7) * 4, 4 do
			local i = y * canvas.canvasWidth * 4 + x
			canvasBuffer[i + 1] = bg.R
			canvasBuffer[i + 2] = bg.G
			canvasBuffer[i + 3] = bg.B
		end
	end
end

-- clears `count` characters (with wrapping) starting from position x,y
local function clearCharacters(canvas: TerminalCanvas, x: number, y: number, count: number): ()
	if count < 0 then
		local _x = x + count
		x = _x % canvas.width
		y = y + _x // canvas.width
		count = math.abs(count)
	end

	local charactersToLineEnd = canvas.width - x
	local overflow = math.min(count - charactersToLineEnd, 0)
	local fullLines = overflow // canvas.width
	local lastLineWidth = overflow % canvas.width

	clearBox(canvas, x, y, math.min(count, charactersToLineEnd), 1)

	if fullLines > 0 then
		clearLines(canvas, y + 1, fullLines)
	end
	if lastLineWidth > 0 then
		clearBox(canvas, 0, y + fullLines + 1, lastLineWidth, 1)
	end
end

local function shiftTerminalUp(canvas: TerminalCanvas, lines: number?): ()
	local _lines = math.clamp(lines or 1, 1, canvas.height)

	if _lines >= canvas.height then
		clearCanvas(canvas)
		return
	end

	-- top-left pixel of the line that would become the top one
	local startPos = (_lines * 16) * canvas.canvasWidth * 4 + 1
	-- bottom-right pixel of the canvas
	local endPos = canvas.canvasHeight * canvas.canvasWidth * 4

	local canvasBuffer = canvas.buffer
	table.move(canvasBuffer, startPos, endPos, 1)

	local height = canvas.height
	clearLines(canvas, height - _lines, _lines)
end

local function shiftTerminalDown(canvas: TerminalCanvas, lines: number?): ()
	local _lines = math.clamp(lines or 1, 1, canvas.height)

	if _lines >= canvas.height then
		clearCanvas(canvas)
		return
	end

	local startPos = 1
	local endPos = _lines * 16 * canvas.canvasWidth * 4

	table.move(canvas.buffer, startPos, endPos, endPos + 1)
	clearLines(canvas, 0, _lines)
end

local function createCanvas(width: characterUnit, height: characterUnit): TerminalCanvas
	-- Actual image size, since width and height represent the size in characters
	local w: pixelUnit, h: pixelUnit = width * 8, height * 16

	local canvas = {
		width = width,
		height = height,
		canvasWidth = w,
		canvasHeight = h,
		buffer = table.create(w * h * 4, 1),
		font = DefaultUnifont,
		bgColor = Colors.Colors8[defaultBGindex],
		fgColor = Colors.Colors8[defaultFGindex],
		attributes = {},
	}

	clearCanvas(canvas)

	return canvas
end

return {
	defaultFGindex = defaultFGindex,
	defaultBGindex = defaultBGindex,
	createCanvas = createCanvas,
	clearCanvas = clearCanvas,
	drawCodepoint = drawCodepoint,
	shiftTerminalUp = shiftTerminalUp,
	shiftTerminalDown = shiftTerminalDown,
	clearBox = clearBox,
	clearCharacters = clearCharacters,
	clearLines = clearLines,
}
