local Renderer = require(script.Parent.renderer)

export type Terminal = {
	canvas: Renderer.TerminalCanvas,
	cursor: Vector2,
	stdin: ((str: string) -> ())?,
	escaping: boolean,
	escapeCodepoint: number | nil,
	escapingState: { number },
	state: { [string]: any },
}

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

local function createTerminal(width: number, height: number): Terminal
	local canvas = Renderer.createCanvas(width, height)
	local terminal: Terminal = {
		canvas = canvas,
		width = width,
		height = height,
		cursor = Vector2.new(0, 0),
		escaping = false,
		escapeCodepoint = nil,
		escapingState = {},
		state = {},
	}
	return terminal
end

return {
	createTerminal = createTerminal,
	writeCodepoint = writeCodepoint,
	moveCursor = moveCursor,
}
