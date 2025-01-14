local parser = require("../parser")
local Canvas = require("../canvas")
local Types = require("../types")
local Handlers = require("./handlers")
local Constants = require("../constants")
local parseUnifont = require("../unifont")
local UNIFONT_ASCII = require("../unifont_ascii")

local vector = require('../vector')

local function noop() end

local function createScreen(canvasType: Canvas.CanvasType, width: number, height: number): Types.TerminalScreen
	local screen: Types.TerminalScreen = {
		canvas = Canvas[canvasType].createCanvas(width, height, 8),
		cursor = vector(0, 0, 0),
		savedCursor = vector(0, 0, 0),
		tabs = table.create(width / Constants.DEFAULT_TAB_WIDTH),
	}

	return screen
end

local function createTerminal(canvasType: Canvas.CanvasType, width: number, height: number, bitmapFont: { buffer }?, theme: { Canvas.RGBA }?): Types.Terminal
	local normalScreen = createScreen(canvasType, width, height)
	local alternateScreen = createScreen(canvasType, width, height)

	local colors = theme or Constants.ANSI_COLORS
	local font = bitmapFont or parseUnifont(UNIFONT_ASCII)

	local terminal: Types.Terminal = {
		canvasType = canvasType,
		currentScreen = normalScreen,
		screens = {
			normal = normalScreen,
			alternate = alternateScreen,
		},
		parser = parser.createParser(),
		handlers = Handlers,
		font = font,
		charsets = {},
		charsetGLevel = 0,
		charset = nil,
		attributes = {
			bold = false,
			italic = false,
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

	Canvas[canvasType].fillScreen(normalScreen.canvas, terminal.bgColor)
	Canvas[canvasType].fillScreen(alternateScreen.canvas, terminal.bgColor)

	return terminal
end

return {
	createTerminal = createTerminal,
}
