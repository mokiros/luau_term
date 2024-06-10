local parser = require(script.Parent.parser)
local canvas = require(script.Parent.canvas)
local Constants = require(script.Parent.Constants)
local Handlers = require(script.Handlers)

local function createTerminal(width: number, height: number, bitmapFont: { buffer }, theme: { canvas.RGBA })
	local terminal: Constants.Terminal = {
		canvas = canvas.createCanvas(width, height, 8),
		parser = parser.createParser(),
		handlers = Handlers,
		cursor = Vector2.new(0, 0),
		font = bitmapFont,
		attributes = {
			bold = false,
			underline = false,
			inverted = false,
		},
		theme = theme,
		fgColor = theme[8],
		fgIndex = 8,
		bgColor = theme[1],
		bgIndex = 1,
	}
	canvas.fillScreen(terminal.canvas, terminal.bgColor)
	return terminal
end

return {
	createTerminal = createTerminal,
}
