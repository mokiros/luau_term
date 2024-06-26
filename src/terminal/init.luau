local parser = require(script.Parent.parser)
local canvas = require(script.Parent.canvas)
local Constants = require(script.Parent.Constants)
local Handlers = require(script.Handlers)

local function createTerminal(width: number, height: number, bitmapFont: { buffer }, theme: { canvas.RGBA })
	local normalScreen: Constants.TerminalScreen = {
		canvas = canvas.createCanvas(width, height, 8),
		cursor = Vector2.new(0, 0),
		savedCursor = Vector2.new(0, 0),
	}
	local alternateScreen: Constants.TerminalScreen = {
		canvas = canvas.createCanvas(width, height, 8),
		cursor = Vector2.new(0, 0),
		savedCursor = Vector2.new(0, 0),
		}
	local terminal: Constants.Terminal = {
		currentScreen = normalScreen,
		screens = {
			normal = normalScreen,
			alternate = alternateScreen,
		},
		parser = parser.createParser(),
		handlers = Handlers,
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
	canvas.fillScreen(normalScreen.canvas, terminal.bgColor)
	canvas.fillScreen(alternateScreen.canvas, terminal.bgColor)
	return terminal
end

return {
	createTerminal = createTerminal,
}
