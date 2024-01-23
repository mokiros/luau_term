local Renderer = require(script.renderer)

export type Terminal = {
	canvas: Renderer.TerminalCanvas,
	width: number,
	height: number,
	cursor: Vector2,
	stdin: ((str: string) -> ())?,
	escaping: boolean,
	escapingState: { any },
}

local ControlCharacters = {
	NUL = 0x00,
	SOH = 0x01,
	STX = 0x02,
	ETX = 0x03,
	EOT = 0x04,
	ENQ = 0x05,
	ACK = 0x06,
	BEL = 0x07,
	BS = 0x08,
	HT = 0x09,
	LF = 0x0A,
	VT = 0x0B,
	FF = 0x0C,
	CR = 0x0D,
	SO = 0x0E,
	SI = 0x0F,
	DLE = 0x10,
	DC1 = 0x11,
	DC2 = 0x12,
	DC3 = 0x13,
	DC4 = 0x14,
	NAK = 0x15,
	SYN = 0x16,
	ETB = 0x17,
	CAN = 0x18,
	EM = 0x19,
	SUB = 0x1A,
	ESC = 0x1B,
	FS = 0x1C,
	GS = 0x1D,
	RS = 0x1E,
	US = 0x1F,
}

local function moveCursor(terminal: Terminal, x: number, y: number, reverseWrap: boolean?, wrapAround: boolean?)
	local cursor = terminal.cursor
	local x1 = cursor.X + x
	local y1 = cursor.Y
		+ y
		+ (if reverseWrap ~= false and wrapAround ~= false then math.floor(x1 // terminal.width) else 0)
	terminal.cursor =
		Vector2.new(if reverseWrap ~= false then x1 % terminal.width else math.clamp(x1, 0, terminal.width - 1), y1)

	-- should reduce it into a single function call
	while terminal.cursor.Y >= terminal.height do
		Renderer.shiftTerminalLineUp(terminal.canvas)
		terminal.cursor -= Vector2.new(0, 1)
	end
end

local function writeCodepoint(terminal: Terminal, codepoint: number)
	local cursor = terminal.cursor
	Renderer.drawCodepoint(terminal.canvas, codepoint, cursor.x, cursor.y)
	moveCursor(terminal, 1, 0)
end

local function processEscapeSequence(terminal: Terminal, codepoint: number): boolean?
	return
end

local function stdout(terminal: Terminal, str: string)
	for i, codepoint in utf8.codes(str) do
		if codepoint < 0x20 then -- Control characters
			if codepoint == ControlCharacters.ESC then
				terminal.escaping = true
				table.clear(terminal.escapingState)
			elseif codepoint == ControlCharacters.BS then
				moveCursor(terminal, -1, 0, false, false)
			elseif codepoint == ControlCharacters.LF then
				moveCursor(terminal, 0, 1)
			elseif codepoint == ControlCharacters.CR then
				terminal.cursor = Vector2.new(0, terminal.cursor.Y)
			elseif codepoint == ControlCharacters.BEL then
				-- TODO: Add bell sound
			end

			continue
		end

		if terminal.escaping then
			local result = processEscapeSequence(terminal, codepoint)
			if result == nil then -- invalid sequence, pass
				terminal.escaping = false
			else
				if result == true then -- finished escape sequence
					terminal.escaping = false
				end
				continue
			end
		end

		writeCodepoint(terminal, codepoint)
	end
end

local function createTerminal(width: number, height: number): Terminal
	local canvas = Renderer.createCanvas(width, height)
	local terminal: Terminal = {
		canvas = canvas,
		width = width,
		height = height,
		cursor = Vector2.new(0, 0),
		escaping = false,
		escapingState = {},
	}
	return terminal
end

return {
	createTerminal = createTerminal,
	stdout = stdout,
}
