local Types = require("./types")
local Terminal = require("./terminal")
local parser = require("./parser")
local Constants = require("./constants")
local Canvas = require("./canvas")
local Util = require("./terminal/util")
local parseUnifont = require("./unifont")

local UNIFONT_ASCII = require("./unifont_ascii")

export type Terminal = Types.Terminal

local function stdout(term: Terminal, buf: buffer, bytesToRead: number?): ()
	local n = bytesToRead or buffer.len(buf)

	for i = 0, n - 1 do
		parser.parse(term, buffer.readu8(buf, i))
	end
end

local function getActiveBuffer(term: Terminal): buffer
	assert(term.canvasType == "Bitmap", `Cannot retrieve active buffer: canvas type is {term.canvasType} (Bitmap expected)`)
	return term.currentScreen.canvas.canvas
end

local function getTextLabelContainers(term: Terminal): (Frame, Frame)
	assert(term.canvasType == "TextLabel", `Cannot retrieve TextLabel containers: canvas type is {term.canvasType} (TextLabel expected)`)
	return term.screens.normal.canvas.canvas.frame, term.screens.alternate.canvas.canvas.frame
end

return {
	stdout = stdout,
	getActiveBuffer = getActiveBuffer,
	getTextLabelContainers = getTextLabelContainers,
	createTerminal = Terminal.createTerminal,
	parseUnifont = parseUnifont,
	Constants = Constants,
	Types = Types,
	Canvas = Canvas,
	Util = Util,
	Parser = parser,
	UNIFONT_ASCII = UNIFONT_ASCII,
}
