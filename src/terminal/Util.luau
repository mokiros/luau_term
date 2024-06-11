local Constants = require(script.Parent.Parent.Constants)
local canvas = require(script.Parent.Parent.canvas)

local Util = {}

Util.cursorForward = function(term: Constants.Terminal, n: number?)
	local cx, cy = term.currentScreen.cursor.X, term.currentScreen.cursor.Y
	local amount = n or 1
	local w = term.currentScreen.canvas.width
	local x, dy = (cx + amount) % w, (cx + amount) // w
	local scroll = cy + dy + 1 - term.currentScreen.canvas.height
	if scroll > 0 then
		canvas.shiftUp(term.currentScreen.canvas, scroll, term.bgColor)
		dy = 0
	end
	term.currentScreen.cursor = Vector2.new(x, cy + dy)
end

Util.cursorBackward = function(term: Constants.Terminal, n: number?)
	local cx, cy = term.currentScreen.cursor.X, term.currentScreen.cursor.Y
	local amount = n or 1
	local w = term.currentScreen.canvas.width
	local x, dy = (cx - amount) % w, (cy - amount) // w
	term.currentScreen.cursor = Vector2.new(x, math.max(cy - dy, 0))
end

Util.cursorUp = function(term: Constants.Terminal, n: number?)
	term.currentScreen.cursor = Vector2.new(term.currentScreen.cursor.X, math.max(term.currentScreen.cursor.Y - (n or 1), 0))
end

Util.cursorDown = function(term: Constants.Terminal, n: number?)
	local y = term.currentScreen.cursor.Y + (n or 1)
	local scroll = math.max(y + 1 - term.currentScreen.canvas.height, 0)
	if scroll > 0 then
		canvas.shiftUp(term.currentScreen.canvas, scroll, term.bgColor)
		y = term.currentScreen.canvas.height - 1
	end
	term.currentScreen.cursor = Vector2.new(term.currentScreen.cursor.X, y)
end

Util.moveCursor = function(term: Constants.Terminal, x: number, y: number)
	local cx, cy = term.currentScreen.cursor.X, term.currentScreen.cursor.Y
	term.currentScreen.cursor = Vector2.new(math.clamp(cx + x, 0, term.currentScreen.canvas.width - 1), math.clamp(cy + y, 0, term.currentScreen.canvas.height - 1))
end

Util.setCursorPosition = function(term: Constants.Terminal, x: number, y: number)
	local w, h = term.currentScreen.canvas.width, term.currentScreen.canvas.height
	term.currentScreen.cursor = Vector2.new(math.clamp(x, 0, w - 1), math.clamp(y, 0, h - 1))
end

return Util
