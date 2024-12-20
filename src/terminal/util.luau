local Types = require("../types")
local canvas = require("../canvas")
local Constants = require("../constants")

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
	if term.currentScreen.cursor.x >= maxX then
		term.currentScreen.cursor = vector.create(maxX - 1, term.currentScreen.cursor.y, 0)
	end
end

Util.shiftRight = function(term: Types.Terminal, amount: number)
	local screen = term.currentScreen
	Util.unsetWrapState(term)
	canvas.shiftRight(screen.canvas, screen.cursor.y, screen.cursor.x, screen.canvas.width - 1, amount, Util.bgColor(term))
end

Util.setCursorPosition = function(term: Types.Terminal, x: number | nil, y: number | nil)
	local screen = term.currentScreen
	local origin = term.decPrivateModes.origin
	local mTop = origin and term.topMargin or 0
	local mBottom = origin and term.bottomMargin or 0
	screen.cursor = vector.create(
		x and math.clamp(x, 0, screen.canvas.width - 1) or screen.cursor.x,
		y and math.clamp(y and y + mTop or screen.cursor.y, mTop, screen.canvas.height - mBottom - 1) or screen.cursor.y,
		0
	)
end

Util.moveCursor = function(term: Types.Terminal, x: number, y: number)
	local screen = term.currentScreen
	Util.setCursorPosition(term, x ~= 0 and screen.cursor.x + x or nil, y ~= 0 and screen.cursor.y + y or nil)
end

Util.cursorUp = function(term: Types.Terminal, amount: number)
	local diffToTop = term.currentScreen.cursor.y - term.topMargin
	Util.moveCursor(term, 0, diffToTop >= 0 and -math.min(diffToTop, amount) or -amount)
end

Util.cursorDown = function(term: Types.Terminal, amount: number)
	local diffToBottom = term.currentScreen.canvas.height - term.bottomMargin - 1 - term.currentScreen.cursor.y
	Util.moveCursor(term, 0, diffToBottom >= 0 and -math.min(diffToBottom, amount) or -amount)
end

Util.cursorLeft = function(term: Types.Terminal, amount: number)
	local screen = term.currentScreen
	local cursor = screen.cursor
	if not term.decPrivateModes.reverseWraparound or not term.decPrivateModes.wraparound then
		screen.cursor = vector.create(math.max(0, cursor.x - amount), cursor.y, 0)
	else
		local scroll = (cursor.x - amount) // screen.canvas.width
		screen.cursor =
			vector.create(math.max(0, cursor.x - amount) % screen.canvas.width, (cursor.y + scroll) % screen.canvas.height, 0)
	end
	Util.unsetWrapState(term)
end

Util.cursorRight = function(term: Types.Terminal, amount: number)
	local screen = term.currentScreen
	local cursor = screen.cursor
	screen.cursor = vector.create(math.min(screen.canvas.width - 1, cursor.x + amount), cursor.y, 0)
end

Util.cursorDownWithScroll = function(term: Types.Terminal)
	local screen = term.currentScreen
	local cursor = screen.cursor
	if cursor.y + 1 == screen.canvas.height - term.bottomMargin then
		Util.scrollUp(term, 1)
	elseif cursor.y + 1 < screen.canvas.height then
		cursor += vector.create(0, 1, 0)
	end
	if cursor.x >= screen.canvas.width then
		cursor += vector.create(-1, 0, 0)
	end
	screen.cursor = cursor
end

Util.cursorUpWithScroll = function(term: Types.Terminal)
	local screen = term.currentScreen
	local cursor = screen.cursor
	if cursor.y == term.topMargin then
		Util.scrollDown(term, 1)
	elseif cursor.y > 0 then
		cursor += vector.create(0, -1, 0)
	end
	if cursor.x >= screen.canvas.width then
		cursor += vector.create(-1, 0, 0)
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
	local x = pos or screen.cursor.x
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
	local x = pos or screen.cursor.x
	for i, v in screen.tabs do
		if v > x then
			return v
		end
	end
	return screen.canvas.width - 1
end

Util.getPreviousTab = function(screen: Types.TerminalScreen, pos: number?): number
	local x = pos or screen.cursor.x
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
