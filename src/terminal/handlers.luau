local canvas = require("../canvas")
local Constants = require("../constants")
local Types = require("../types")
local Util = require("./util")
local Unicode = require("../unicode")

local vector = require("../vector")

local FunctionIdentifier = require("./function_identifier")
local fi = FunctionIdentifier.identifier
local identifierToString = FunctionIdentifier.identifierToString
local C0, C1 = Constants.C0, Constants.C1

local Handlers = {
	csi = {},
	dcs = {},
	osc = {},
	esc = {},
	exec = {},
	print = function() end,
	error = function() end,
} :: Types.Handlers

local function fiEsc(params)
	return fi(params, { 0x30, 0x7e })
end

local underlineGlyph = buffer.create(16)
buffer.writeu8(underlineGlyph, 12, 0xFF)

Handlers.print = function(term, code)
	local shouldPrint, codepoint = Unicode.process(code, term.parser.joinState)
	if not shouldPrint then
		term.parser.joinState = codepoint
		return
	end
	term.parser.joinState = 0

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
	local charset = term.charset
	if charset and charset[codepoint] then
		codepoint = charset[codepoint]
	end
	local bitmapGlyph = term.font[codepoint] or term.font[0xFFFD] or error(`Unknown codepoint: {codepoint}`)
	local screen = term.currentScreen
	local charWidth = buffer.len(bitmapGlyph) / (screen.canvas.cellSize * 2)
	if screen.cursor.x + charWidth > screen.canvas.width then
		if term.decPrivateModes.wraparound then
			local nextY = screen.cursor.y + 1
			if nextY == (screen.canvas.height - term.bottomMargin) then
				nextY -= 1
				Util.scrollUp(term, 1)
			elseif nextY >= screen.canvas.height then
				nextY = screen.canvas.height - 1
			end
			Util.setCursorPosition(term, 0, nextY)
		else
			Util.moveCursor(term, -1, 0)
		end
	end
	local cursor = screen.cursor
	if term.modes.insert then
		Util.shiftRight(term, charWidth)
	end
	canvas.drawBitmap(screen.canvas, cursor.x, cursor.y, bitmapGlyph, fgColor, bgColor)
	if term.attributes.underline then
		canvas.drawBitmap(screen.canvas, cursor.x, cursor.y, underlineGlyph, fgColor)
	end
	screen.cursor += vector(charWidth, 0, 0)
	term.lastPrintedCodepoint = codepoint
end

Handlers.error = function(term) end
Handlers.csiFallback = function(term, ident, params)
	warn(`Unknown CSI code: {identifierToString(ident)}, params: {table.concat(params, ", ")}`)
end
Handlers.escFallback = function(term, code)
	warn(`Unknown ESC code: {identifierToString(code)}`)
end
Handlers.execFallback = function(term, code)
	warn(`Unknown EXECUTE code: {string.format("%02X", code)}`)
end
Handlers.oscFallback = function(term, ident, data, dataLength)
	local b = buffer.create(dataLength)
	buffer.copy(b, 0, data, 0, dataLength)
	warn(`Unknown OSC code: {ident}, data: {buffer.tostring(b)}`)
end
Handlers.dcsFallback = function(term, ident, data, dataLength, params)
	local b = buffer.create(dataLength)
	buffer.copy(b, 0, data, 0, dataLength)
	warn(`Unknown DCS code: {identifierToString(ident)}, data: {buffer.tostring(b)}, params: {table.concat(params, ", ")}`)
end

----------------
-- CSI HANDLERS

-- ESC [ n @ - insert blanks
Handlers.csi[fi({ final = "@" })] = function(term, params)
	Util.shiftRight(term, params.params[1] or 1)
end

-- ESC [ n A - cursor up
Handlers.csi[fi({ final = "A" })] = function(term, params)
	local amount = params.params[1] or 1
	Util.cursorUp(term, amount)
end

-- ESC [ n B - cursor down
Handlers.csi[fi({ final = "B" })] = function(term, params)
	local amount = params.params[1] or 1
	Util.cursorDown(term, amount)
end

-- ESC [ n C - cursor right
Handlers.csi[fi({ final = "C" })] = function(term, params)
	local amount = params.params[1] or 1
	Util.moveCursor(term, amount, 0)
end

-- ESC [ n D - cursor left
Handlers.csi[fi({ final = "D" })] = function(term, params)
	local amount = params.params[1] or 1
	if amount == 0 then
		amount = 1
	end
	Util.cursorLeft(term, amount)
end

-- ESC [ n E - cursor down and to the beginning of the line
Handlers.csi[fi({ final = "E" })] = function(term, params)
	local amount = params.params[1] or 1
	Util.cursorDown(term, amount)
	Util.setCursorPosition(term, 0, nil)
end

-- ESC [ n F - cursor up and to the beginning of the line
Handlers.csi[fi({ final = "F" })] = function(term, params)
	local amount = params.params[1] or 1
	Util.cursorUp(term, amount)
	Util.setCursorPosition(term, 0, nil)
end

-- ESC [ n G - absolute horizontal position
Handlers.csi[fi({ final = "G" })] = function(term, params)
	local x = params.params[1] or 1
	Util.setCursorPosition(term, x - 1, nil)
end

-- ESC [ n H - cursor position
Handlers.csi[fi({ final = "H" })] = function(term, params)
	local column = params.params[1] or 1
	local row = params.params[2] or 1
	Util.setCursorPosition(term, row - 1, column - 1)
end

-- ESC [ n I - forward tab
Handlers.csi[fi({ final = "I" })] = function(term, params)
	local screen = term.currentScreen

	if screen.cursor.x >= screen.canvas.width then
		return
	end

	local amount = params.params[1] or 1
	for i = 1, amount do
		Util.setCursorPosition(term, Util.getNextTab(screen), nil)
	end
end

-- ESC [ n J - erase in display
Handlers.csi[fi({ final = "J" })] = function(term, params)
	local screen = term.currentScreen
	local mode = params.params[1] or 0

	Util.unsetWrapState(term)

	if mode == 0 then
		for x = screen.cursor.x, screen.canvas.width - 1 do
			canvas.fillCell(screen.canvas, x, screen.cursor.y, Util.bgColor(term))
		end
		local lines = screen.canvas.height - screen.cursor.y - 1
		if lines > 0 then
			canvas.fillLines(screen.canvas, screen.cursor.y + 1, lines, Util.bgColor(term))
		end
	elseif mode == 1 then
		local lines = screen.cursor.y - 1
		if lines > 0 then
			canvas.fillLines(screen.canvas, 0, lines, Util.bgColor(term))
		end
		for x = 0, screen.cursor.x do
			canvas.fillCell(screen.canvas, x, screen.cursor.y, Util.bgColor(term))
		end
	elseif mode == 2 or mode == 3 then
		canvas.fillScreen(screen.canvas, Util.bgColor(term))
	end
end

-- ESC [ ? n J - erase in display (protected mode, not implemented here)
Handlers.csi[fi({ prefix = "?", final = "J" })] = Handlers.csi[fi({ final = "J" })]

-- ESC [ n K - erase in line
Handlers.csi[fi({ final = "K" })] = function(term, params)
	local screen = term.currentScreen
	local mode = params.params[1] or 0

	Util.unsetWrapState(term)

	if mode == 0 then
		for x = screen.cursor.x, screen.canvas.width - 1 do
			canvas.fillCell(screen.canvas, x, screen.cursor.y, Util.bgColor(term))
		end
	elseif mode == 1 then
		for x = 0, screen.cursor.x do
			canvas.fillCell(screen.canvas, x, screen.cursor.y, Util.bgColor(term))
		end
	elseif mode == 2 then
		canvas.fillLines(screen.canvas, screen.cursor.y, 1, Util.bgColor(term))
	end
end

-- ESC [ ? n K - erase in line (protected mode, not implemented here)
Handlers.csi[fi({ prefix = "?", final = "K" })] = Handlers.csi[fi({ final = "K" })]

-- ESC [ n L - insert lines
Handlers.csi[fi({ final = "L" })] = function(term, params)
	local screen = term.currentScreen
	local amount = params.params[1] or 1
	Util.unsetWrapState(term)

	if screen.cursor.y < term.topMargin or screen.cursor.y > term.bottomMargin then
		return
	end

	canvas.shiftDown(screen.canvas, amount, screen.cursor.y, term.bottomMargin, Util.bgColor(term))
	Util.setCursorPosition(term, 0, nil)
end

-- ESC [ n M - delete lines
Handlers.csi[fi({ final = "M" })] = function(term, params)
	local screen = term.currentScreen
	local amount = params.params[1] or 1
	Util.unsetWrapState(term)

	if screen.cursor.y < term.topMargin or screen.cursor.y > term.bottomMargin then
		return
	end

	canvas.shiftUp(screen.canvas, amount, screen.cursor.y, term.bottomMargin, Util.bgColor(term))
	Util.setCursorPosition(term, 0, nil)
end

-- ESC [ n P - delete chars
Handlers.csi[fi({ final = "P" })] = function(term, params)
	local screen = term.currentScreen
	local amount = params.params[1] or 1
	Util.unsetWrapState(term)
	canvas.shiftLeft(screen.canvas, screen.cursor.y, screen.cursor.x, screen.canvas.width - 1, amount, Util.bgColor(term))
end

-- ESC [ n S - scroll up
Handlers.csi[fi({ final = "S" })] = function(term, params)
	local amount = params.params[1] or 1
	Util.scrollUp(term, amount)
end

-- ESC [ n T - scroll down
Handlers.csi[fi({ final = "T" })] = function(term, params)
	local amount = params.params[1] or 1
	Util.scrollDown(term, amount)
end

-- ESC [ n X - erase chars
Handlers.csi[fi({ final = "X" })] = function(term, params)
	local screen = term.currentScreen
	local amount = params.params[1] or 1
	local endX = math.min(screen.cursor.x + amount - 1, screen.canvas.width - 1)
	Util.unsetWrapState(term)
	for x = screen.cursor.x, endX do
		canvas.fillCell(screen.canvas, x, screen.cursor.y, Util.bgColor(term))
	end
end

-- ESC [ n Z - cursor backward tab
Handlers.csi[fi({ final = "Z" })] = function(term, params)
	local screen = term.currentScreen

	if screen.cursor.x <= 0 then
		return
	end

	local amount = params.params[1] or 1
	for i = 1, amount do
		Util.setCursorPosition(term, Util.getPreviousTab(screen), nil)
	end
end

-- ESC [ n ` - cursor horizontal pos
Handlers.csi[fi({ final = "`" })] = function(term, params)
	local x = params.params[1] or 1
	Util.setCursorPosition(term, x - 1, nil)
end

-- ESC [ n a - move cursor horizontally
Handlers.csi[fi({ final = "a" })] = function(term, params)
	local amount = params.params[1] or 1
	Util.moveCursor(term, amount, 0)
end

-- ESC [ n b - repeat previously printed character
Handlers.csi[fi({ final = "b" })] = function(term, params)
	local amount = params.params[1] or 1
	local code = term.lastPrintedCodepoint
	for i = 1, amount do
		Handlers.print(term, code)
	end
end

-- ESC [ n c - primary device attributes
Handlers.csi[fi({ final = "c" })] = function(term, params)
	warn("FIXME: Program requested Primary Device Attributes (DA1)")
end

-- ESC [ > n c - secondary device attributes
Handlers.csi[fi({ prefix = ">", final = "c" })] = function(term, params)
	warn("FIXME: Program requested Secondary Device Attributes (DA2)")
end

-- ESC [ = n c - tertiary device attributes
Handlers.csi[fi({ prefix = "=", final = "c" })] = function(term, params)
	warn("FIXME: Program requested Tertiary Device Attributes (DA3)")
end

-- ESC [ n d - absolute vertical pos
Handlers.csi[fi({ final = "d" })] = function(term, params)
	local y = math.max(params.params[1] or 1, 1)
	Util.unsetWrapState(term)
	Util.setCursorPosition(term, nil, y - 1)
end

-- ESC [ n e - move cursor vertically
Handlers.csi[fi({ final = "e" })] = function(term, params)
	local amount = params.params[1] or 1
	Util.unsetWrapState(term)
	Util.moveCursor(term, 0, amount)
end

-- ESC [ n f - cursor position, alias for ESC [ n H
Handlers.csi[fi({ final = "f" })] = Handlers.csi[fi({ final = "H" })]

-- ESC [ n g - tab clear
Handlers.csi[fi({ final = "g" })] = function(term, params)
	local screen = term.currentScreen
	local mode = params.params[1] or 0
	if mode == 0 then
		local x = screen.cursor.x
		for i, v in term.currentScreen.tabs do
			if v == x then
				table.remove(term.currentScreen.tabs, i)
			elseif v > x then
				break
			end
		end
	elseif mode == 3 then
		table.clear(term.currentScreen.tabs)
	end
end

-- ESC [ [n] h - set mode
Handlers.csi[fi({ final = "h" })] = function(term, params)
	for i, v in params.params do
		if v == 4 then
			term.modes.insert = true
		elseif v == 20 then
			term.options.convertEol = true
		end
	end
end

-- ESC[ ? [n] h - set private mode
Handlers.csi[fi({ prefix = "?", final = "h" })] = function(term, params)
	for i, v in params.params do
		if v == 1 then
			term.decPrivateModes.applicationCursorKeys = true
			term:changeCursorKeyFormat(true)
		elseif v == 6 then
			term.decPrivateModes.origin = true
			Util.setCursorPosition(term, 0, 0)
		elseif v == 7 then
			term.decPrivateModes.wraparound = true
		elseif v == 12 then
			term.options.cursorBlink = true
		elseif v == 45 then
			term.decPrivateModes.reverseWraparound = true
		elseif v == 25 then
			term.cursorHidden = true
			term:changeCursorVisibility(true)
		elseif v == 2004 then
			term.decPrivateModes.bracketedPasteMode = true
			term:changeBracketedPasteMode(true)
		elseif v == 1048 or v == 1049 then
			Util.saveCursor(term.currentScreen)
		end

		-- Separate if check so that 1049 would additionally call `saveCursor` above
		if v == 47 or v == 1047 or v == 1049 then
			Util.switchToAltScreen(term)
		end
	end
end

-- ESC [ [n] l - reset mode
Handlers.csi[fi({ final = "l" })] = function(term, params)
	for i, v in params.params do
		if v == 4 then
			term.modes.insert = false
		elseif v == 20 then
			term.options.convertEol = false
		end
	end
end

-- ESC [ ? [n] l - reset private mode
Handlers.csi[fi({ prefix = "?", final = "l" })] = function(term, params)
	for i, v in params.params do
		if v == 1 then
			term.decPrivateModes.applicationCursorKeys = false
			term:changeCursorKeyFormat(false)
		elseif v == 6 then
			term.decPrivateModes.origin = false
			Util.setCursorPosition(term, 0, 0)
		elseif v == 7 then
			term.decPrivateModes.wraparound = false
		elseif v == 12 then
			term.options.cursorBlink = false
		elseif v == 45 then
			term.decPrivateModes.reverseWraparound = false
		elseif v == 25 then
			term.cursorHidden = false
			term:changeCursorVisibility(false)
		elseif v == 2004 then
			term.decPrivateModes.bracketedPasteMode = false
			term:changeBracketedPasteMode(false)
		elseif v == 1048 or v == 1049 then
			Util.restoreCursor(term.currentScreen)
		end

		if v == 47 or v == 1047 or v == 1049 then
			Util.switchToNormalScreen(term)
		end
	end
end

-- ESC [ [n] m - set graphics rendition (SGR)
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
			local clr = 0xff000000
			local t = params.params
			local offset = i
			local mode = 0
			if params.subParams[i] then
				t = params.subParams[i]
				mode = t[1] or 0
				offset = 2
			elseif params.subParams[i + 1] then
				t = params.subParams[i + 1]
				mode = params.params[i + 1]
				offset = 1
				i += 1
			else
				t = params.params
				offset = i + 2
				mode = params.params[i + 1]
				if mode == 2 then
					i += 3
				elseif mode == 5 then
					i += 1
				end
				i += 1
			end
			if mode == 2 then
				local r = t[offset + 0] or 0
				local g = t[offset + 1] or 0
				local b = t[offset + 2] or 0
				clr = r * 0x1 + g * 0x100 + b * 0x10000 + 0xff000000
			elseif mode == 5 then
				clr = term.theme[(t[offset + 0] or 0) + 1] or clr
			end
			if param == 38 then
				term.fgColor = clr
				term.fgIndex = 0
			else
				term.bgColor = clr
				term.bgIndex = 0
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

-- ESC [ n r - set top and bottom margins
Handlers.csi[fi({ final = "r" })] = function(term, params)
	local height = term.currentScreen.canvas.height
	local mTop = params.params[1] or 1
	local mBottom = params.params[2] or height
	if mBottom == 0 or mBottom > height then
		mBottom = height
	end
	if mTop < mBottom then
		term.topMargin = mTop - 1
		term.bottomMargin = height - mBottom
		Util.setCursorPosition(term, 0, 0)
	else
		term.topMargin = 0
		term.bottomMargin = height
	end
end

-- ESC [ n s - save cursor
Handlers.csi[fi({ final = "s" })] = function(term, params)
	Util.saveCursor(term.currentScreen)
end

----------------
-- EXEC HANDLERS

Handlers.exec[C0.BEL] = function(term)
	local bell = term.bell
	if bell then
		bell(term)
	end
end

Handlers.exec[C0.LF] = function(term)
	if term.options.convertEol then
		term.currentScreen.cursor = vector(0, term.currentScreen.cursor.y, 0)
	end
	Util.cursorDownWithScroll(term)
end
Handlers.exec[C0.VT] = Handlers.exec[C0.LF]
Handlers.exec[C0.FF] = Handlers.exec[C0.LF]

Handlers.exec[C0.CR] = function(term)
	term.currentScreen.cursor = vector(0, term.currentScreen.cursor.y, 0)
end

Handlers.exec[C0.BS] = function(term)
	Util.cursorLeft(term, 1)
end

Handlers.exec[C0.HT] = function(term)
	Util.setCursorPosition(term, Util.getNextTab(term.currentScreen), nil)
end

Handlers.exec[C1.IND] = function(term)
	Util.cursorDownWithScroll(term)
end

Handlers.exec[C1.RI] = function(term)
	Util.cursorUpWithScroll(term)
end

Handlers.exec[C1.NEL] = function(term)
	Util.setCursorPosition(term, 0, nil)
	Util.cursorDownWithScroll(term)
end

Handlers.exec[C1.HTS] = function(term)
	Util.insertTab(term.currentScreen)
end

----------------
-- OSC HANDLERS

-- icon name and title
Handlers.osc[0] = function(term, buf, len)
	local str = buffer.readstring(buf, 0, len)
	warn("FIXME: Program set icon and title: " .. str)
end

-- icon
Handlers.osc[1] = function(term, buf, len)
	local str = buffer.readstring(buf, 0, len)
	warn("FIXME: Program set icon: " .. str)
end

-- title
Handlers.osc[2] = function(term, buf, len)
	local str = buffer.readstring(buf, 0, len)
	warn("FIXME: Program set title: " .. str)
end

Handlers.osc[4] = function(term, buf, len)
	warn("FIXME: Program requested indexed color")
end

-- hyperlink
Handlers.osc[8] = function(term, buf, len)
	-- ignore it
end

----------------
-- ESC HANDLERS

-- ESC \ -- ignore
Handlers.esc[fiEsc({ final = "\\" })] = function() end

-- ESC 7 - save cursor
Handlers.esc[fiEsc({ final = "7" })] = function(term)
	Util.saveCursor(term.currentScreen)
end

-- ESC 8 - restore cursor
Handlers.esc[fiEsc({ final = "8" })] = function(term)
	Util.restoreCursor(term.currentScreen)
end

-- ESC D - index
Handlers.esc[fiEsc({ final = "D" })] = Handlers.exec[C1.IND]

-- ESC E - next line
Handlers.esc[fiEsc({ final = "E" })] = Handlers.exec[C1.NEL]

-- ESC H - set tab
Handlers.esc[fiEsc({ final = "H" })] = Handlers.exec[C1.HTS]

-- ESC M - reverse index
Handlers.esc[fiEsc({ final = "M" })] = Handlers.exec[C1.RI]

-- ESC c - full reset
Handlers.esc[fiEsc({ final = "c" })] = function(term)
	warn("FIXME: Program requested full reset")
end

-- ESC ( B - set charset to default
Handlers.esc[fiEsc({ intermediates = { "(" }, final = "B" })] = function()
	-- TODO: implement charset support
end

table.freeze(Handlers.esc)
table.freeze(Handlers.csi)
table.freeze(Handlers.dcs)
table.freeze(Handlers.osc)
table.freeze(Handlers.exec)
table.freeze(Handlers)

return Handlers
