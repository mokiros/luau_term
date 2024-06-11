local createHandlers = require(script.Parent.Parent.parser.Handlers).createHandlers
local canvas = require(script.Parent.Parent.canvas)
local Constants = require(script.Parent.Parent.Constants)
local Util = require(script.Parent.Util)

local fi = require(script.Parent.Parent.parser.FunctionIdentifier).identifier
local C0, C1 = Constants.C0, Constants.C1

local Handlers = createHandlers()

local underlineGlyph = buffer.create(8)
buffer.writeu8(underlineGlyph, 6, 0xFF)

Handlers.print = function(term, code)
	local bitmapGlyph = term.font[code] or term.font[0xFFFD] or error(`Unknown codepoint: {code}`)
	local screen = term.currentScreen
	local cursor = screen.cursor
	local fgColor = term.fgColor
	local fgIndex = term.fgIndex
	local bgColor = term.bgColor
	local bgIndex = term.bgIndex
	if term.attributes.inverted then
		fgColor, bgColor = bgColor, fgColor
		fgIndex, bgIndex = bgIndex, fgIndex
	end
	if term.attributes.bold and fgIndex ~= 0 then
		fgColor = term.theme[(fgIndex % 8) + 8]
	end
	canvas.drawBitmap(screen.canvas, cursor.X, cursor.Y, bitmapGlyph, fgColor, bgColor)
	if term.attributes.underline then
		canvas.drawBitmap(screen.canvas, cursor.X, cursor.Y, underlineGlyph, fgColor, bgColor)
	end
	Util.cursorForward(term, 1)
end

Handlers.error = function(term) end

Handlers.csi[fi({ final = "H" })] = function(term, params)
	local x = params.params[2] or 1
	local y = params.params[1] or 1
	Util.setCursorPosition(term, x - 1, y - 1)
end

Handlers.csi[fi({ final = "J" })] = function(term, params)
	local screen = term.currentScreen
	local mode = params.params[1] or 0
	if mode == 0 then
		canvas.fillBetween(
			screen.canvas,
			screen.cursor.X,
			screen.cursor.Y,
			screen.canvas.width - 1,
			screen.canvas.height - 1,
			term.bgColor
		)
	elseif mode == 1 then
		canvas.fillBetween(screen.canvas, 0, 0, screen.cursor.X, screen.cursor.Y, term.bgColor)
	elseif mode == 2 or mode == 3 then
		canvas.fillScreen(screen.canvas, term.bgColor)
	end
end

Handlers.csi[fi({ final = "A" })] = function(term, params)
	local amount = math.max(params.params[1] or 1, 1)
	Util.moveCursor(term, 0, -amount)
end

Handlers.csi[fi({ final = "B" })] = function(term, params)
	local amount = math.max(params.params[1] or 1, 1)
	Util.moveCursor(term, 0, amount)
end

Handlers.csi[fi({ final = "C" })] = function(term, params)
	local amount = math.max(params.params[1] or 1, 1)
	Util.moveCursor(term, amount, 0)
end

Handlers.csi[fi({ final = "D" })] = function(term, params)
	local amount = math.max(params.params[1] or 1, 1)
	Util.moveCursor(term, -amount, 0)
end

Handlers.csi[fi({ final = "m" })] = function(term, params)
	local function sgr0()
		term.attributes.bold = false
		term.attributes.underline = false
		term.attributes.inverted = false
		term.fgIndex = 8
		term.bgIndex = 1
		term.fgColor = term.theme[term.fgIndex]
		term.bgColor = term.theme[term.bgIndex]
	end
	if params._length == 0 or (params._length == 1 and params.params[1] == 0) then
		sgr0()
	end
	local i = 1
	while i <= params._length do
		local param = params.params[i]
		if param >= 30 and param <= 37 then
			term.fgIndex = (param % 10) + 1
			term.fgColor = term.theme[term.fgIndex]
		elseif param >= 40 and param <= 47 then
			term.bgIndex = (param % 10) + 1
			term.bgColor = term.theme[term.bgIndex]
		elseif param >= 90 and param <= 97 then
			term.fgIndex = (param % 10) + 9
			term.fgColor = term.theme[term.fgIndex]
		elseif param >= 100 and param <= 107 then
			term.bgIndex = (param % 10) + 9
			term.bgColor = term.theme[term.bgIndex]
		elseif param == 0 then
			sgr0()
		elseif param == 1 then
			term.attributes.bold = true
		elseif param == 4 then
			term.attributes.underline = true
		elseif param == 7 then
			term.attributes.inverted = true
		elseif param == 22 then
			term.attributes.bold = false
		elseif param == 24 then
			term.attributes.underline = false
		elseif param == 27 then
			term.attributes.inverted = false
		elseif param == 38 or param == 48 then
			i += 1
			local mode = params.params[i]
			if mode == 2 then
				local r, g, b = params.params[i + 1] or 0, params.params[i + 2] or 0, params.params[i + 3] or 0
				i += 3
				local clr = { r / 255, g / 255, b / 255, 1 }
				if param == 38 then
					term.fgColor = clr
					term.fgIndex = 0
				else
					term.bgColor = clr
					term.bgIndex = 0
				end
			end
		elseif param == 39 then
			term.fgIndex = 8
			term.fgColor = term.theme[8]
		elseif param == 49 then
			term.bgIndex = 1
			term.bgColor = term.theme[1]
		else
			warn(`Unimplemented SGR param: {param}`)
		end
		i += 1
	end
end

Handlers.csi[fi({ final = "K" })] = function(term, params)
	local screen = term.currentScreen
	local mode = params.params[1] or 0
	if mode == 0 then
		canvas.fillBetween(screen.canvas, screen.cursor.X, screen.cursor.Y, screen.canvas.width - 1, screen.cursor.Y, term.bgColor)
	end
end

Handlers.csi[fi({ prefix = "?", final = "h" })] = function(term, params)
	local screen = term.currentScreen
	local mode = params.params[1] or 0
	if mode == 47 or mode == 1047 or mode == 1049 then
		if mode == 1049 then
			screen.savedCursor = screen.cursor
		end
		if screen ~= term.screens.alternate then
			screen = term.screens.alternate
			screen.cursor = term.screens.normal.cursor
			canvas.fillScreen(screen.canvas, term.theme[1])
			term.currentScreen = screen
		end
	elseif mode == 2004 then
		-- bracketed paste mode, ignore for now because no clipboard functionality
	end
end

Handlers.csi[fi({ prefix = "?", final = "l" })] = function(term, params)
	local screen = term.currentScreen
	local mode = params.params[1] or 0
	if mode == 47 or mode == 1047 or mode == 1049 then
		if screen ~= term.screens.normal then
			screen = term.screens.normal
			screen.cursor = term.screens.alternate.cursor
			term.currentScreen = screen
		end
		if mode == 1049 then
			screen.cursor = screen.savedCursor
		end
	elseif mode == 2004 then
		-- same as above
	end
end

-- ESC 7 - Save cursor
Handlers.esc[0x37] = function(term)
	local screen = term.currentScreen
	screen.savedCursor = screen.cursor
end

-- ESC 8 - Restore cursor
Handlers.esc[0x38] = function(term)
	local screen = term.currentScreen
	screen.cursor = screen.savedCursor
end

Handlers.exec[C0.CR] = function(term)
	Util.setCursorPosition(term, 0, term.currentScreen.cursor.Y)
end

Handlers.exec[C0.LF] = function(term)
	Util.cursorDown(term, 1)
end

Handlers.exec[C0.BS] = function(term)
	Util.moveCursor(term, -1, 0)
end

return Handlers
