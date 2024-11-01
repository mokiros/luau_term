local Types = require(script.Parent.Parent.Types)
local canvas = require(script.Parent.Parent.canvas)
local Constants = require(script.Parent.Parent.Constants)

local Util = {}

Util.bgColor = function(term: Types.Terminal)
	return if term.attributes.inverted then term.fgColor else term.bgColor
end

Util.fgColor = function(term: Types.Terminal)
	return if term.attributes.inverted then term.bgColor else term.fgColor
end

Util.scrollUp = function(term: Types.Terminal, amount: number)
	local screen = term.currentScreen
	canvas.shiftUp(screen.canvas, amount, term.topMargin, term.bottomMargin, Util.bgColor(term))
end

Util.scrollDown = function(term: Types.Terminal, amount: number)
	local screen = term.currentScreen
	canvas.shiftDown(screen.canvas, amount, term.topMargin, term.bottomMargin, Util.bgColor(term))
end

Util.unsetWrapState = function(term: Types.Terminal)
	local maxX = term.currentScreen.canvas.width
	if term.currentScreen.cursor.X >= maxX then
		term.currentScreen.cursor = Vector2.new(maxX - 1, term.currentScreen.cursor.Y)
	end
end

Util.shiftRight = function(term: Types.Terminal, amount: number)
	local screen = term.currentScreen
	Util.unsetWrapState(term)
	canvas.shiftRight(screen.canvas, screen.cursor.Y, screen.cursor.X, screen.canvas.width, amount, Util.bgColor(term))
end

Util.setCursorPosition = function(term: Types.Terminal, x: number | nil, y: number | nil)
	local screen = term.currentScreen
	local origin = term.decPrivateModes.origin
	local mTop = origin and term.topMargin or 0
	local mBottom = origin and term.bottomMargin or 0
	screen.cursor = Vector2.new(
		x and math.clamp(x, 0, screen.canvas.width - 1) or screen.cursor.X,
		y and math.clamp(y and y + mTop or screen.cursor.Y, mTop, screen.canvas.height - mBottom - 1) or screen.cursor.Y
	)
end

Util.moveCursor = function(term: Types.Terminal, x: number, y: number)
	local screen = term.currentScreen
	Util.setCursorPosition(term, x ~= 0 and screen.cursor.X + x or nil, y ~= 0 and screen.cursor.Y + y or nil)
end

Util.cursorUp = function(term: Types.Terminal, amount: number)
	local diffToTop = term.currentScreen.cursor.Y - term.topMargin
	Util.moveCursor(term, 0, diffToTop >= 0 and -math.min(diffToTop, amount) or -amount)
end

Util.cursorDown = function(term: Types.Terminal, amount: number)
	local diffToBottom = term.currentScreen.canvas.height - term.bottomMargin - 1 - term.currentScreen.cursor.Y
	Util.moveCursor(term, 0, diffToBottom >= 0 and -math.min(diffToBottom, amount) or -amount)
end

Util.cursorLeft = function(term: Types.Terminal, amount: number)
	local screen = term.currentScreen
	local cursor = screen.cursor
	if not term.decPrivateModes.reverseWraparound or not term.decPrivateModes.wraparound then
		screen.cursor = Vector2.new(math.max(0, cursor.X - amount), cursor.Y)
	else
		local scroll = (cursor.X - amount) // screen.canvas.width
		screen.cursor =
			Vector2.new(math.max(0, cursor.X - amount) % screen.canvas.width, (cursor.Y + scroll) % screen.canvas.height)
	end
	Util.unsetWrapState(term)
end

Util.cursorRight = function(term: Types.Terminal, amount: number)
	local screen = term.currentScreen
	local cursor = screen.cursor
	screen.cursor = Vector2.new(math.min(screen.canvas.width - 1, cursor.X + amount), cursor.Y)
end

Util.cursorDownWithScroll = function(term: Types.Terminal)
	local screen = term.currentScreen
	local cursor = screen.cursor
	if cursor.Y + 1 == screen.canvas.height - term.bottomMargin then
		Util.scrollUp(term, 1)
	elseif cursor.Y + 1 < screen.canvas.height then
		cursor += Vector2.new(0, 1)
	end
	if cursor.X >= screen.canvas.width then
		cursor += Vector2.new(-1, 0)
	end
	screen.cursor = cursor
end

Util.cursorUpWithScroll = function(term: Types.Terminal)
	local screen = term.currentScreen
	local cursor = screen.cursor
	if cursor.Y == term.topMargin then
		Util.scrollDown(term, 1)
	elseif cursor.Y > 0 then
		cursor += Vector2.new(0, -1)
	end
	if cursor.X >= screen.canvas.width then
		cursor += Vector2.new(-1, 0)
	end
	screen.cursor = cursor
end

Util.saveCursor = function(screen: Types.TerminalScreen)
	screen.savedCursor = screen.cursor
end

Util.restoreCursor = function(screen: Types.TerminalScreen)
	screen.cursor = screen.savedCursor
end

Util.resetTabs = function(screen: Types.TerminalScreen)
	table.clear(screen.tabs)
	for i = 0, screen.canvas.width - 1, Constants.DEFAULT_TAB_WIDTH do
		table.insert(screen.tabs, i)
	end
end

Util.insertTab = function(screen: Types.TerminalScreen, pos: number?)
	local x = pos or screen.cursor.X
	for i, v in screen.tabs do
		if v > x then
			table.insert(screen.tabs, i, x)
			return
		elseif v == x then
			return
		end
	end
end

Util.getNextTab = function(screen: Types.TerminalScreen, pos: number?): number
	local x = pos or screen.cursor.X
	for i, v in screen.tabs do
		if v > x then
			return v
		end
	end
	return screen.canvas.width - 1
end

Util.getPreviousTab = function(screen: Types.TerminalScreen, pos: number?): number
	local x = pos or screen.cursor.X
	for i, v in screen.tabs do
		if v >= x then
			return screen.tabs[i - 1] or 0
		end
	end
	return 0
end

Util.switchToAltScreen = function(term: Types.Terminal)
	if term.currentScreen == term.screens.alternate then
		return
	end
	canvas.fillScreen(term.screens.alternate.canvas, term.bgColor)
	term.screens.alternate.cursor = term.screens.normal.cursor
	term.currentScreen = term.screens.alternate
end

Util.switchToNormalScreen = function(term: Types.Terminal)
	if term.currentScreen == term.screens.normal then
		return
	end
	canvas.fillScreen(term.screens.alternate.canvas, term.bgColor)
	term.screens.normal.cursor = term.screens.alternate.cursor
	term.currentScreen = term.screens.normal
end

return table.freeze(Util)
