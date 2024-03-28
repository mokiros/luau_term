local createHandlers = require(script.Parent.Parent.parser.Handlers).createHandlers
local Util = require(script.Parent.Util)
local canvas = require(script.Parent.Parent.canvas)

local Handlers = createHandlers()

Handlers.print = function(term, code)
	print("print", code)
	local bitmapGlyph = term.font[code] or term.font[0xFFFD] or error(`Unknown codepoint: {code}`)
	local cursor = term.cursor
	canvas.drawBitmap(term.canvas, cursor.X, cursor.Y, bitmapGlyph, term.fgColor, term.bgColor)
	local newCursor = cursor + Vector2.new(1, 0)
	if newCursor.X >= term.canvas.width then
		newCursor = Vector2.new(0, cursor.Y + 1)
		if newCursor.Y >= term.canvas.height then
			newCursor = Vector2.new(0, cursor.Y)
			canvas.shiftUp(term.canvas, 1)
		end
	end
	term.cursor = newCursor
end

Handlers.error = function(term) end

return Handlers
