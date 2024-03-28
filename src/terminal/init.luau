local parser = require(script.Parent.parser)
local canvas = require(script.Parent.canvas)
local Constants = require(script.Parent.Constants)
local Handlers = require(script.Handlers)

local function createTerminal(width: number, height: number, bitmapFont: { buffer })
	local terminal: Constants.Terminal = {
		canvas = canvas.createCanvas(width, height, 8),
		parser = parser.createParser(),
		handlers = Handlers,
		cursor = Vector2.new(0, 0),
		font = bitmapFont,
		fgColor = { 1, 1, 1, 1 },
		bgColor = { 0, 0.25, 0.25, 1 },
	}
	canvas.fillScreen(terminal.canvas, terminal.bgColor)
	return terminal
end

return {
	createTerminal = createTerminal,
}
