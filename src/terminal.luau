local Renderer = require(script.Parent.renderer)

export type Terminal = {
	canvas: Renderer.TerminalCanvas,
	cursor: Vector2,
	escaping: boolean,
	state: { [string]: any },

	-- Double buffered escape state
	-- Used for cases like String Terminator sequence, where a previous
	-- escape sequence buffer is required
	escapingState: { number },
	escapingState_previousBuffer: { number },
	escapeCodepoint: number | nil,
	escapeCodepoint_previous: number | nil,

	-- callback function to transmit terminal messages to the shell
	stdin: ((term: Terminal, str: string) -> ())?,
}

-- Used by the terminal to transmit escape sequences back to tty
local function stdin(term: Terminal, str: string): ()
	if term.stdin then
		term.stdin(term, str)
	end
end

-- Helper function to send "ESC [ <sequence> <finalByte>" to stdin
local function sendEscapeSequence(term: Terminal, finalByte: string, sequence: { any }?): ()
	stdin(term, "\27[" .. (sequence and table.concat(sequence, ";") or "") .. finalByte)
end

-- moves the cursor across the terminal
-- if noWrap is true, cursor stays at the edges
local function moveCursor(term: Terminal, x: number, y: number, noWrap: boolean?)
	local cursor = term.cursor
	local x1 = cursor.X + x
	local y1 = cursor.Y + y + (if noWrap ~= true then x1 // term.canvas.width else 0)

	if noWrap ~= true then
		local overflow = y1 - term.canvas.height + 1
		if overflow > 0 then
			Renderer.shiftTerminalUp(term.canvas, overflow)
		end
	end

	term.cursor = Vector2.new(
		if noWrap then x1 % term.canvas.width else math.clamp(x1, 0, term.canvas.width - 1),
		math.clamp(y1, 0, term.canvas.height - 1)
	)
end

local function writeCodepoint(term: Terminal, codepoint: number)
	local cursor = term.cursor
	Renderer.drawCodepoint(term.canvas, codepoint, cursor.X, cursor.Y)
	moveCursor(term, 1, 0)
end

local function createTerminal(width: number, height: number, fonts: Renderer.TerminalFonts): Terminal
	local canvas = Renderer.createCanvas(width, height, fonts)
	local terminal: Terminal = {
		canvas = canvas,
		width = width,
		height = height,
		cursor = Vector2.new(0, 0),
		escaping = false,
		escapeCodepoint = nil,
		escapingState = {},
		escapingState_previousBuffer = {},
		state = {},
	}
	return terminal
end

return {
	createTerminal = createTerminal,
	writeCodepoint = writeCodepoint,
	moveCursor = moveCursor,
	stdin = stdin,
	sendEscapeSequence = sendEscapeSequence,
}
