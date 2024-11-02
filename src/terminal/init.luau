local parser = require(script.Parent.parser)
local canvas = require(script.Parent.canvas)
local Types = require(script.Parent.Types)
local Handlers = require(script.Handlers)
local Charsets = require(script.Parent.Charsets)
local Constants = require(script.Parent.Constants)

local function noop() end

local function createScreen(width: number, height: number): Types.TerminalScreen
	local screen: Types.TerminalScreen = {
		canvas = canvas.createCanvas(width, height, 8),
		cursor = Vector2.new(0, 0),
		savedCursor = Vector2.new(0, 0),
		tabs = table.create(width / Constants.DEFAULT_TAB_WIDTH),
	}

	return screen
end

local function createTerminal(width: number, height: number, bitmapFont: { buffer }, theme: { canvas.RGBA }?): Types.Terminal
	local normalScreen = createScreen(width, height)
	local alternateScreen = createScreen(width, height)

	local colors = theme or Constants.ANSI_COLORS

	local terminal: Types.Terminal = {
		currentScreen = normalScreen,
		screens = {
			normal = normalScreen,
			alternate = alternateScreen,
		},
		parser = parser.createParser(),
		handlers = Handlers,
		font = bitmapFont,
		charset = Charsets[0],
		attributes = {
			bold = false,
			underline = false,
			inverted = false,
		},
		topMargin = 0,
		bottomMargin = 0,
		lastPrintedCodepoint = 0,
		cursorHidden = false,
		options = {
			convertEol = false,
			cursorBlink = true,
		},
		modes = {
			insert = false,
		},
		decPrivateModes = {
			applicationCursorKeys = false,
			applicationKeypad = false,
			bracketedPasteMode = false,
			origin = false,
			reverseWraparound = false,
			sendFocus = false,
			wraparound = true,
		},
		theme = colors,
		fgColor = colors[8],
		fgIndex = 8,
		bgColor = colors[1],
		bgIndex = 1,

		stdin = noop,
		bell = noop,
		changeCursorKeyFormat = noop,
		changeCursorVisibility = noop,
		changeBracketedPasteMode = noop,
	}

	canvas.fillScreen(normalScreen.canvas, terminal.bgColor)
	canvas.fillScreen(alternateScreen.canvas, terminal.bgColor)

	return terminal
end

return {
	createTerminal = createTerminal,
}
