local Constants = require(script.Parent.Parent.Constants)
local canvas = require(script.Parent.Parent.canvas)

local Util = {}

Util.cursorForward = function(term: Constants.Terminal, n: number?)
	local cx, cy = term.cursor.X, term.cursor.Y
	local amount = n or 1
	local w = term.canvas.width
	local x, dy = (cx + amount) % w, (cx + amount) // w
	local scroll = cy + dy + 1 - term.canvas.height
	if scroll > 0 then
		canvas.shiftUp(term.canvas, scroll, term.bgColor)
		dy = 0
	end
	term.cursor = Vector2.new(x, cy + dy)
end

Util.cursorBackward = function(term: Constants.Terminal, n: number?)
	local cx, cy = term.cursor.X, term.cursor.Y
	local amount = n or 1
	local w = term.canvas.width
	local x, dy = (cx - amount) % w, (cy - amount) // w
	term.cursor = Vector2.new(x, math.max(cy - dy, 0))
end

Util.cursorUp = function(term: Constants.Terminal, n: number?)
	term.cursor = Vector2.new(term.cursor.X, math.max(term.cursor.Y - (n or 1), 0))
end

Util.cursorDown = function(term: Constants.Terminal, n: number?)
	local y = term.cursor.Y + (n or 1)
	local scroll = math.max(y + 1 - term.canvas.height, 0)
	if scroll > 0 then
		canvas.shiftUp(term.canvas, scroll, term.bgColor)
		y = term.canvas.height - 1
	end
	term.cursor = Vector2.new(term.cursor.X, y)
end

Util.moveCursor = function(term: Constants.Terminal, x: number, y: number)
	local cx, cy = term.cursor.X, term.cursor.Y
	term.cursor = Vector2.new(math.clamp(cx + x, 0, term.canvas.width - 1), math.clamp(cy + y, 0, term.canvas.height - 1))
end

Util.setCursorPosition = function(term: Constants.Terminal, x: number, y: number)
	local w, h = term.canvas.width, term.canvas.height
	term.cursor = Vector2.new(math.clamp(x, 0, w - 1), math.clamp(y, 0, h - 1))
end

return Util
