local createHandlers = require(script.Parent.Parent.parser.Handlers).createHandlers
local canvas = require(script.Parent.Parent.canvas)
local Constants = require(script.Parent.Parent.Constants)
local Util = require(script.Parent.Util)

local fi = require(script.Parent.Parent.parser.FunctionIdentifier).identifier
local C0, C1 = Constants.C0, Constants.C1

local Handlers = createHandlers()

Handlers.print = function(term, code)
	local bitmapGlyph = term.font[code] or term.font[0xFFFD] or error(`Unknown codepoint: {code}`)
	local cursor = term.cursor
	canvas.drawBitmap(term.canvas, cursor.X, cursor.Y, bitmapGlyph, term.fgColor, term.bgColor)
	Util.cursorForward(term, 1)
end

Handlers.error = function(term) end

Handlers.csi[fi({ final = "H" })] = function(term, params)
	Util.setCursorPosition(term, params.params[2] or 1, params.params[1] or 1)
end

Handlers.csi[fi({ final = "J" })] = function(term, params)
	local mode = params.params[1] or 0
	if mode == 0 then
		canvas.fillBetween(term.canvas, term.cursor.X, term.cursor.Y, term.canvas.width - 1, term.canvas.height - 1, term.bgColor)
	elseif mode == 1 then
		canvas.fillBetween(term.canvas, 0, 0, term.cursor.X, term.cursor.Y, term.bgColor)
	elseif mode == 2 or mode == 3 then
		canvas.fillScreen(term.canvas, term.bgColor)
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
	local i = 1
	while i <= params._length do
		local param = params.params[i]
		if param == 38 or param == 48 then
			i += 1
			local mode = params.params[i]
			if mode == 1 then
				warn(`STUB: 8 bit color not implemented`)
			elseif mode == 2 then
				local r, g, b = params.params[i + 1] or 0, params.params[i + 2] or 0, params.params[i + 3] or 0
				i += 3
				local clr = { r / 255, g / 255, b / 255, 1 }
				if param == 38 then
					term.fgColor = clr
				else
					term.bgColor = clr
				end
			end
		else
			warn(`Unimplemented SGR param: {param}`)
		end
		i += 1
	end
end

Handlers.csi[fi({ final = "K" })] = function(term, params)
	local mode = params.params[1] or 0
	if mode == 0 then
		canvas.fillBetween(term.canvas, term.cursor.X, term.cursor.Y, term.canvas.width - 1, term.cursor.Y, term.bgColor)
	end
end

Handlers.exec[C0.CR] = function(term)
	Util.setCursorPosition(term, 0, term.cursor.Y)
end

Handlers.exec[C0.LF] = function(term)
	Util.cursorDown(term, 1)
end

Handlers.exec[C0.BS] = function(term)
	Util.moveCursor(term, -1, 0)
end

return Handlers
