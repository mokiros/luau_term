local Terminal = require(script.Parent.Parent.terminal)
local Renderer = require(script.Parent.Parent.renderer)
local Colors = require(script.Parent.colors)

-- for better readability
local ESC = string.byte
local b = string.byte

-- Read a number from a sequence of codepoints
local function readNumber(sequence: { number }): number?
	local len = #sequence
	if len > 4 then
		warn(`Number sequence too long: length is {len}`)
		return nil
	end
	local str = string.char(table.unpack(sequence))
	local n = tonumber(str)
	if not n then
		return nil
	end
	return math.clamp(n, 0, 9999)
end

local function readNumbersWithSemicolon(sequence: { number }): { number }
	local len = #sequence
	if len > 255 then
		warn(`Number sequence too long: length is {len}`)
		return {}
	end
	local str = string.char(table.unpack(sequence))
	local numbers: { string | number | nil } = string.split(str, ";")
	for k, v in numbers do
		numbers[k] = tonumber(v) or 0
	end
	return numbers :: { number }
end

local CSIHandlers: { [number]: (term: Terminal.Terminal, state: { number }) -> () } = {
	-- CSI n A - cursor up
	[b("A")] = function(term, state)
		local y = readNumber(state) or 1
		Terminal.moveCursor(term, 0, -y)
	end,

	-- CSI n B - cursor down
	[b("B")] = function(term, state)
		local y = readNumber(state) or 1
		Terminal.moveCursor(term, 0, y)
	end,

	-- CSI n C - cursor forward
	[b("C")] = function(term, state)
		local x = readNumber(state) or 1
		Terminal.moveCursor(term, x, 0)
	end,

	-- CSI n D - cursor back
	[b("D")] = function(term, state)
		local x = readNumber(state) or 1
		Terminal.moveCursor(term, -x, 0)
	end,

	-- CSI n E - cursor next line
	[b("E")] = function(term, state)
		local cursor = term.cursor
		local lines = readNumber(state) or 1
		term.cursor = Vector2.new(0, cursor.Y)
		Terminal.moveCursor(term, 0, lines)
	end,

	-- CSI n F - cursor previous line
	[b("E")] = function(term, state)
		local cursor = term.cursor
		local lines = readNumber(state) or 1
		term.cursor = Vector2.new(0, cursor.Y)
		Terminal.moveCursor(term, 0, -lines)
	end,

	-- CSI n G - cursor horizontal absolute
	[b("G")] = function(term, state)
		local cursor = term.cursor
		local line = readNumber(state) or 1
		term.cursor = Vector2.new(cursor.X, line)
	end,

	-- CSI n H - cursor position
	[b("H")] = function(term, state)
		local numbers = readNumbersWithSemicolon(state)
		local y = numbers[1] or 1
		local x = numbers[2] or 1
		term.cursor =
			Vector2.new(math.clamp(x - 1, 0, term.canvas.width - 1), math.clamp(y - 1, 0, term.canvas.height - 1))
	end,

	-- CSI n J - erase in display
	[b("J")] = function(term, state)
		local num = readNumber(state)
		local cursorPosition = term.cursor.Y * term.canvas.width + term.cursor.X
		if num == nil or num == 0 then -- erase from cursor to the end of display
			local termLength = term.canvas.width * term.canvas.height
			Renderer.clearCharacters(term.canvas, term.cursor.X, term.cursor.Y, termLength - cursorPosition)
		elseif num == 1 then -- erase from beginning of display to cursor
			Renderer.clearCharacters(term.canvas, 0, 0, cursorPosition)
		elseif num == 2 or num == 3 then -- erase entire display
			Renderer.clearCanvas(term.canvas)
			term.cursor = Vector2.zero
		else
			warn(`Invalid Erase in Display value: {num}`)
		end
	end,

	-- CSI n K - erase in line
	[b("K")] = function(term, state)
		local num = readNumber(state)
		local y = term.cursor.Y
		if num == nil or num == 0 then -- erase from cursor to end of line
			Renderer.clearBox(term.canvas, term.cursor.X, y, term.canvas.width - term.cursor.X, 1)
		elseif num == 1 then -- erase from start of line to cursor
			Renderer.clearBox(term.canvas, 0, y, term.cursor.X + 1, 1)
		elseif num == 2 then -- erase entire line
			Renderer.clearLines(term.canvas, y)
		else
			warn(`Invalid Erase in Line value: {num}`)
		end
	end,

	-- CSI n S - scroll up
	[b("S")] = function(term, state)
		local num = readNumber(state) or 1
		Renderer.shiftTerminalUp(term.canvas, num)
	end,

	-- CSI n T - scroll down
	[b("T")] = function(term, state)
		local num = readNumber(state) or 1
		Renderer.shiftTerminalDown(term.canvas, num)
	end,

	-- CSI [n] m - SGR (Select Graphic Rendition) my beloved
	-- where all the color magic happens
	[b("m")] = function(term, state)
		local numbers = readNumbersWithSemicolon(state)
		local num = numbers[1]
		if num == nil or num == 0 then -- reset
			table.clear(term.canvas.attributes)
			term.canvas.bgColor = Colors.Colors8[Renderer.defaultBGindex]
			term.canvas.fgColor = Colors.Colors8[Renderer.defaultFGindex]
		elseif num == 1 then -- bold
			local idx = term.canvas.attributes["fg_colorIndex"] or Renderer.defaultFGindex
			term.canvas.fgColor = Colors.Colors8[idx + 8]
			term.canvas.attributes["bold"] = true
		elseif num == 22 then -- normal intensity (not bold or faint)
			local idx = term.canvas.attributes["fg_colorIndex"] or Renderer.defaultFGindex
			term.canvas.fgColor = Colors.Colors8[idx]
			term.canvas.attributes["bold"] = nil
		elseif num >= 30 and num <= 37 then -- 3 bit foreground color
			local idx = num % 10 + 1
			term.canvas.attributes["fg_colorIndex"] = idx
			if term.canvas.attributes["bold"] then
				idx += 8 -- brighter color
			end
			term.canvas.fgColor = Colors.Colors8[idx]
		elseif num == 39 then -- reset foreground color
			term.canvas.attributes["fg_colorIndex"] = nil
			local idx = Renderer.defaultFGindex
			if term.canvas.attributes["bold"] then
				idx += 8
			end
			term.canvas.fgColor = Colors.Colors8[idx]
		elseif num >= 40 and num <= 47 then -- 3 bit background color
			local idx = num % 10 + 1
			term.canvas.attributes["bg_colorIndex"] = idx
			term.canvas.bgColor = Colors.Colors8[idx]
		elseif num == 49 then -- reset background color
			term.canvas.attributes["bg_colorIndex"] = nil
			local idx = Renderer.defaultBGindex
			term.canvas.bgColor = Colors.Colors8[idx]
		elseif num == 38 or num == 48 then -- 8/24 bit foreground colors
			local mode = numbers[2]
			if mode == 5 then -- 8 bit
				-- TODO: 8 bit color lookup table or manually calculate it
				local idx = numbers[3]
				warn(`STUB: Encountered 8 bit color: {idx}`)
			elseif mode == 2 then -- 24 bit
				local r, g, b = numbers[3], numbers[4], numbers[5]
				local clr = Color3.fromRGB(r or 0, g or 0, b or 0)
				if num == 38 then -- foreground
					term.canvas.attributes["fg_colorIndex"] = nil
					term.canvas.fgColor = clr
				else -- background
					term.canvas.attributes["bg_colorIndex"] = nil
					term.canvas.bgColor = clr
				end
			else
				warn(`Unsupported color mode: {mode}`)
			end
		else
			warn(`Unknown SGR code: {num}`)
		end
	end,

	-- CSI 6n - Device Status Report
	[b("n")] = function(term, state)
		local num = readNumber(state)
		if num == 6 then
			local cursor = term.cursor
			Terminal.sendEscapeSequence(term, "R", { cursor.Y + 1, cursor.X + 1 })
		else
			warn(`Unknown DSR code: {num}`)
		end
	end,
}

CSIHandlers[b("f")] = CSIHandlers[b("H")]

local SequenceHandlers: { [number]: (term: Terminal.Terminal, state: { number }) -> boolean? } = {

	-- Control Sequence Introducer
	[ESC("[")] = function(term, state)
		local len = #state
		if len == 0 then
			return false
		elseif len > 255 then
			warn(`Escape sequence length exceeded 255, cancelling`)
			term.escaping = false
			return true
		end
		local codepoint = state[len]
		if codepoint < 0x20 or codepoint > 0x7E then
			warn(`Codepoint outside of escape sequence range: {utf8.char(codepoint)}`)
			term.escaping = false
			return false
		end
		if codepoint >= 0x40 then -- final byte
			table.remove(state)
			local handler = CSIHandlers[codepoint]
			if not handler then
				warn(`Unknown CSI final byte: {utf8.char(codepoint)}`)
			else
				handler(term, state)
			end
			return true
		end
		return false
	end,

	-- Single Shift Two
	[ESC("N")] = function(term, state)
		warn(`Unsupported Single Shift Two sequence encountered`)
		return true
	end,

	-- Single Shift Three
	[ESC("O")] = function(term, state)
		warn(`Unsupported Single Shift Three sequence encountered`)
		return true
	end,

	-- Device Control String
	[ESC("P")] = function(term, state)
		-- Do nothing, the state will be processed in String Terminator sequence
		return false
	end,

	-- String Terminator
	[ESC("\\")] = function(term)
		local codepoint = term.escapeCodepoint_previous
		local state = term.escapingState_previousBuffer
		warn(
			`STUB: String Terminator encountered, previous code: {codepoint and string.char(codepoint) or nil}, previous state: {string.char(
				table.unpack(state)
			)}`
		)
		return true
	end,
}

local function processEscapeCodepoint(term: Terminal.Terminal, codepoint: number): boolean
	local state = term.escapingState
	if not term.escapeCodepoint then
		term.escapeCodepoint = codepoint
	else
		table.insert(state, codepoint)
		if #state > 255 then
			warn(`Escape sequence state exceeded limit, cancelling`)
			term.escaping = false
			return false
		end
	end
	local handler = SequenceHandlers[term.escapeCodepoint :: number]
	if not handler then
		warn(`Unrecognized escape sequence: {utf8.char(codepoint)}`)
		term.escaping = false
		return true
	end
	local result = handler(term, state)
	if result ~= false then
		term.escaping = false
	end
	return true
end

return processEscapeCodepoint
