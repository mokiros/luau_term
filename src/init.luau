local Types = require("./types")
local Terminal = require("./terminal")
local parser = require("./parser")
local Constants = require("./constants")
local Canvas = require("./canvas")
local Util = require("./terminal/util")
local parseUnifont = require("./unifont")

local UNIFONT_ASCII = require("./unifont_ascii")

local function stdout(term: Types.Terminal, buf: buffer, bytesToRead: number?): ()
	local n = bytesToRead or buffer.len(buf)

	for i = 0, n - 1 do
		parser.parse(term, buffer.readu8(buf, i))
	end
end

export type Terminal = Types.Terminal

return {
	stdout = stdout,
	createTerminal = Terminal.createTerminal,
	parseUnifont = parseUnifont,
	Constants = Constants,
	Types = Types,
	Canvas = Canvas,
	Util = Util,
	Parser = parser,
	UNIFONT_ASCII = UNIFONT_ASCII,
}
